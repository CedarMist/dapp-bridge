import { ethers } from "hardhat";
import { expect } from "chai";
import { EndpointOnEthereum, EndpointOnSapphire, MockCelerMessageBus } from "../typechain-types";
import { getCreateAddress, parseEther } from "ethers"
import { randomBytes } from "crypto";

const SAPPHIRE_LOCALNET_CHAINID = 0x5afd;
const ETHEREUM_CHAINID = 1;

describe('End to end', () => {
    let mockmb: MockCelerMessageBus;
    let eos: EndpointOnSapphire;
    let eoe: EndpointOnEthereum;

    before(async () => {
        const [owner] = await ethers.getSigners();

        const mockmbfactory = await ethers.getContractFactory('MockCelerMessageBus');
        mockmb = await mockmbfactory.deploy();
        await mockmb.waitForDeployment()

        // Predict deployment addresses of both endpoints
        const eosNonce = await ethers.provider.getTransactionCount(owner);
        const eosAddress = getCreateAddress({from: owner.address, nonce: eosNonce});
        const eoeNonce = eosNonce + 1;
        const eoeAddress = getCreateAddress({from: owner.address, nonce: eoeNonce});

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

        expect(await eoe.remoteSigner()).equal(eosSigner);

        // Then add the contract mappings via the Mock MessageBus so they can talk to each other
        await mockmb["addContract(address,uint64)"](eosAddress, SAPPHIRE_LOCALNET_CHAINID);
        await mockmb["addContract(address,uint64)"](eoeAddress, ETHEREUM_CHAINID);
    });

    it('Ping Pong', async () => {
        console.log('Delivered count', await mockmb.deliveredCount());
        console.log('Undelivered count', await mockmb.undeliveredCount());

        console.log('Sending ping');
        const eosPingRand = randomBytes(32);
        const eosPing = await eos.ping(eosPingRand, {value: parseEther('1')})
        const eosPingReceipt = await eosPing.wait();
        console.log(eosPingReceipt);

        console.log('Undelivered count', await mockmb.undeliveredCount());
        console.log('Delivering ping')

        const eosPingDelivery = await mockmb.deliverOneMessage();
        const eosPingDeliveryReceipt = eosPingDelivery.wait();
        console.log(eosPingDeliveryReceipt);

        console.log('Delivered count', await mockmb.deliveredCount());
        console.log('Undelivered count', await mockmb.undeliveredCount());
    });
});
