import { ethers } from "hardhat";
import { expect } from "chai";
import { EndpointOnEthereum, EndpointOnSapphire, MockCelerMessageBus, WrappedROSE } from "../typechain-types";
import { EventFragment, getCreateAddress, hexlify, parseEther } from "ethers"
import { randomBytes } from "crypto";

const SAPPHIRE_LOCALNET_CHAINID = 0x5afd;
const ETHEREUM_CHAINID = 1;

describe('End to end', () => {
    let mockmb: MockCelerMessageBus;
    let eos: EndpointOnSapphire;
    let eoe: EndpointOnEthereum;
    let pongFragment: EventFragment;
    let wROSE: WrappedROSE;

    before(async () => {
        const [owner] = await ethers.getSigners();

        // Predict deployment addresses of both endpoints
        const eosNonce = await ethers.provider.getTransactionCount(owner) + 1;
        const eosAddress = getCreateAddress({from: owner.address, nonce: eosNonce});
        const eoeNonce = eosNonce + 1;
        const eoeAddress = getCreateAddress({from: owner.address, nonce: eoeNonce});

        const mockmbfactory = await ethers.getContractFactory('MockCelerMessageBus');
        mockmb = await mockmbfactory.deploy([
            {remoteContract: eosAddress, remoteChainId: SAPPHIRE_LOCALNET_CHAINID, localContract: eosAddress},
            {remoteContract: eoeAddress, remoteChainId: ETHEREUM_CHAINID, localContract: eoeAddress},
        ]);
        await mockmb.waitForDeployment()

        // Deploy sapphire endpoint first
        const eosFactory = await ethers.getContractFactory('EndpointOnSapphire');
        eos = await eosFactory.deploy(mockmb.getAddress(), eoeAddress, ETHEREUM_CHAINID);
        await eos.waitForDeployment();
        expect(await eos.getAddress()).equal(eosAddress);
        const eosSigner = await eos.signingPublic();

        // Then ethereum endpoint
        const eoeFactory = await ethers.getContractFactory('EndpointOnEthereum');
        eoe = await eoeFactory.deploy(mockmb.getAddress(), eosAddress, SAPPHIRE_LOCALNET_CHAINID, eosSigner);
        await eoe.waitForDeployment();
        expect(await eoe.getAddress()).equal(eoeAddress);

        wROSE = await ethers.getContractAt('WrappedROSE', await eoe.token());

        // Verify Ethereum endpoint has correct signer from Sapphire endpoint
        expect(await eoe.remoteSigner()).equal(eosSigner);

        pongFragment = eoe.interface.getEvent("Pong");
    });

    it('Ping Sapphire to Ethereum', async () => {
        const dcBefore = await mockmb.deliveredCount();
        const udcBefore = await mockmb.undeliveredCount();

        // Send a ping() event from Sapphire to Ethereum
        const eosPingRand = randomBytes(32);
        const eosPing = await eos.ping(eosPingRand, {value: parseEther('1')})
        await eosPing.wait();

        // Verify an undelivered message is pending
        expect(await mockmb.undeliveredCount()).equal(udcBefore + 1n);
        expect(await mockmb.deliveredCount()).equal(dcBefore);

        // Deliver a single message
        const eosPingDelivery = await mockmb.deliverOneMessage();
        const eosPingDeliveryReceipt = await eosPingDelivery.wait();

        // Verify delivery emitted pong event with correct randomness
        let foundPongEvent = false;
        for( const l of eosPingDeliveryReceipt!.logs ) {
            if( l.topics.includes(pongFragment.topicHash) ) {
                foundPongEvent = true;
                expect(l.data).equal(hexlify(eosPingRand));
            }
        }
        expect(foundPongEvent).equal(true);

        // Verify message have been delivered
        expect(await mockmb.undeliveredCount()).equal(udcBefore);
        expect(await mockmb.deliveredCount()).equal(dcBefore + 1n);
    });

    it('Ping Ethereum to Sapphire', async () => {
        const dcBefore = await mockmb.deliveredCount();
        const udcBefore = await mockmb.undeliveredCount();

        // Send a ping() event from Sapphire to Ethereum
        const eoePingRand = randomBytes(32);
        const eoePing = await eoe.ping(eoePingRand, {value: parseEther('1')})
        await eoePing.wait();

        // Verify an undelivered message is pending
        expect(await mockmb.undeliveredCount()).equal(udcBefore + 1n);
        expect(await mockmb.deliveredCount()).equal(dcBefore);

        // Deliver a single message
        const eoePingDelivery = await mockmb.deliverOneMessage();
        const eoePingDeliveryReceipt = await eoePingDelivery.wait();

        // Verify delivery emitted pong event with correct randomness
        let foundPongEvent = false;
        for( const l of eoePingDeliveryReceipt!.logs ) {
            if( l.topics.includes(pongFragment.topicHash) ) {
                foundPongEvent = true;
                expect(l.data).equal(hexlify(eoePingRand));
            }
        }
        expect(foundPongEvent).equal(true);

        // Verify messages have been delivered
        expect(await mockmb.undeliveredCount()).equal(udcBefore);
        expect(await mockmb.deliveredCount()).equal(dcBefore + 1n);
    });

    it('Mint & Burn', async () => {
        const dcBefore = await mockmb.deliveredCount();
        const udcBefore = await mockmb.undeliveredCount();

        const [owner] = await ethers.getSigners();

        // Deposit cost is subtracted from amount sent to contract
        // Provide the cost in addition to the amount
        const eosDepositAmount = parseEther('1');
        const eosDepositCost = await eos.depositCost();

        const eosDepositTx = await eos["deposit()"]({value: eosDepositCost + eosDepositAmount});
        await eosDepositTx.wait();

        // Verify an undelivered message is pending
        expect(await mockmb.undeliveredCount()).equal(udcBefore + 1n);
        expect(await mockmb.deliveredCount()).equal(dcBefore);

        // Deliver a single message
        const eoeDepositDeliveryTx = await mockmb.deliverOneMessage();
        await eoeDepositDeliveryTx.wait();

        // Verify message have been delivered
        expect(await mockmb.undeliveredCount()).equal(udcBefore);
        expect(await mockmb.deliveredCount()).equal(dcBefore + 1n);

        // Verify 1 wROSE has been minted
        expect(await wROSE.balanceOf(owner.address)).equal(eosDepositAmount);
    });
});
