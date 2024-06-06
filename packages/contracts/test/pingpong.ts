import { ethers } from "hardhat";
import { expect } from "chai";
import { MockPingPong, MockCelerMessageBus, MockPingPong__factory } from "../typechain-types";
import { getBytes, getCreateAddress, hexlify } from "ethers"
import { randomBytes } from "crypto";

const SAPPHIRE_LOCALNET_CHAINID = 0x5afd;
const ETHEREUM_CHAINID = 1;
const LONGER_TIMEOUT_MS = (1000 * 60 * 2); // 2 minutes is a longer timeout!

function makePingPongTests(contractName:string)
{
    describe(contractName, () => {
        let mockmb: MockCelerMessageBus;
        let ppA: MockPingPong;
        let ppB: MockPingPong;

        before(async function () {
            this.timeout(LONGER_TIMEOUT_MS);

            const [owner] = await ethers.getSigners();

            // Predict deployment addresses of both endpoints
            const ppANonce = await ethers.provider.getTransactionCount(owner) + 1;
            const ppAAddress = getCreateAddress({from: owner.address, nonce: ppANonce});
            const ppBNonce = ppANonce + 1;
            const ppBAddress = getCreateAddress({from: owner.address, nonce: ppBNonce});

            // Deploy mock messagebus, initialized with remappings
            const mockmbfactory = await ethers.getContractFactory('MockCelerMessageBus');
            mockmb = await mockmbfactory.deploy([
                {remoteContract: ppAAddress, remoteChainId: SAPPHIRE_LOCALNET_CHAINID, localContract:ppAAddress},
                {remoteContract: ppBAddress, remoteChainId: ETHEREUM_CHAINID, localContract:ppBAddress}
            ]);
            await mockmb.waitForDeployment();

            const ppFactory = await ethers.getContractFactory(contractName) as MockPingPong__factory;

            // Deploy sapphire endpoint first
            ppA = await ppFactory.deploy(
                mockmb.getAddress(),
                ppBAddress,
                ETHEREUM_CHAINID);
            await ppA.waitForDeployment();
            expect(await ppA._celer_messageBus()).equal(await mockmb.getAddress());

            // Then ethereum endpoint
            ppB = await ppFactory.deploy(
                mockmb.getAddress(),
                ppAAddress,
                SAPPHIRE_LOCALNET_CHAINID);
            await ppB.waitForDeployment();
            expect(await ppB._celer_messageBus()).equal(await mockmb.getAddress());
        });

        it('Ping', async function () {
            this.timeout(LONGER_TIMEOUT_MS);

            expect(await mockmb.deliveredCount()).equal(0);
            expect(await mockmb.undeliveredCount()).equal(0);

            // Send ping from contract A to B
            const ppAPingRand = randomBytes(32);

            const ppAMessageLength = await ppA.pingMessageLength.staticCall();
            const ppAMessage = getBytes(await ppA.pingMessage.staticCall(ppAPingRand));
            expect(ppAMessageLength).equal(ppAMessage.length);

            const ppAMessageFee = await mockmb.calcFee(ppAMessage);
            const ppACost = await ppA.pingCost();
            expect(ppACost).equal(ppAMessageFee);

            const ppAPing = await ppA.ping(ppAPingRand, {value: ppACost})
            await ppAPing.wait();

            expect(await mockmb.undeliveredCount()).equal(1);
            expect(await mockmb.deliveredCount()).equal(0);

            // Deliver ping message to contract B via MessageBus
            const ppAPingDelivery = await mockmb.deliverOneMessage();
            const ppAPingReceipt = await ppAPingDelivery.wait();

            // Verify emitted event matches what we input
            expect(ppAPingReceipt?.logs[0].data).equal(hexlify(ppAPingRand));

            expect(await mockmb.undeliveredCount()).equal(0);
            expect(await mockmb.deliveredCount()).equal(1);
        });
    });
}

makePingPongTests('MockPingPong');
makePingPongTests('MockPingPongUsingEndpoint');
makePingPongTests('MockPingPongUsingSpoke');
makePingPongTests('MockPingPongUsingSpokeMessengerUnique');
//makePingPongTests('MockPingPongUsingSpokeMessengerSignedUnique');