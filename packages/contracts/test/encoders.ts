import { ethers } from "hardhat";
import { expect } from "chai";
import { TestDecoders, TestEncoders, TestUniqueMessageDecoder, TestUniqueMessageEncoder } from "../typechain-types";
import { AbiCoder, EventLog, Signature, SigningKey, computeAddress, getBytes, hexlify, keccak256, randomBytes } from "ethers";
import { OutputDataEvent } from "../typechain-types/contracts/tests/TestEncoders.sol/TestEncoders";

const LONGER_TIMEOUT = 1000 * 100;

describe('Signed Encoding & Decoding', () => {
    let te: TestEncoders;
    let teOutputData: OutputDataEvent.Event;
    let td: TestDecoders;

    before(async () => {
        const ef = await ethers.getContractFactory('TestEncoders');
        te = await ef.deploy()
        await te.waitForDeployment();
        teOutputData = te.getEvent('OutputData');

        const df = await ethers.getContractFactory('TestDecoders');
        td = await df.deploy(await te.signingPublic())
        await td.waitForDeployment();
    });

    it('Unique', async function () {
        this.timeout(LONGER_TIMEOUT);

        for( let i = 0; i < 65; i += 16 ) {
            const inputData = randomBytes(i);

            // Encode in tx, and verify it can be decoded
            const encodeTx = await te.testUnique(inputData);
            const encodeReceipt = await encodeTx.wait();
            const el = encodeReceipt!.logs[0] as EventLog;
            const encodedData = el.args[0];
            const expectedLength = el.args[1];

            // Expected length of encoded data matches actual encoded length
            expect(getBytes(encodedData).length).equal(expectedLength);

            // Message can be decoded in view call
            const staticDecoded = await td.testUnique.staticCall(encodedData);
            expect(staticDecoded).equal(hexlify(inputData));

            // Submit unique message on-chain
            // to prevent same tag from being received again
            const decodeTx = await td.testUnique(encodedData);
            await decodeTx.wait();

            // Verify it can't be submitted again
            expect(td.testUnique.staticCall(encodedData)).revertedWith("duplicate message");
        }
    });

    it('Signing Linkage', async () => {
        expect(await td.remoteSigner()).equal(await te.signingPublic());
    })

    it('Signed', async function () {
        this.timeout(LONGER_TIMEOUT);
        for( let i = 0; i < 65; i += 16 ) {
            const inputData = randomBytes(i);
            const c = await te.testSigned.staticCall(inputData);
            const digest = keccak256(inputData);

            expect(getBytes(c.out_data).length).equal(c.out_predictedLength);

            // Verify signature can be decoded
            const sigData = AbiCoder.defaultAbiCoder().decode(['bytes32[2]', 'bytes'], c.out_data);
            const sig = Signature.from({
                r: sigData[0][0],
                yParityAndS: sigData[0][1]
            });
            expect(sigData[1]).equal(hexlify(inputData));

            const recoveredAddress = SigningKey.recoverPublicKey(digest, sig);
            expect(computeAddress(recoveredAddress)).equal(await te.signingPublic());
            expect(computeAddress(recoveredAddress)).equal(await td.remoteSigner());

            const decoded = await td.testSigned.staticCall(c.out_data);
            expect(decoded).equal(hexlify(inputData));
        }
    });

    it('Signed Unique', async function() {
        this.timeout(LONGER_TIMEOUT);
        for( let i = 0; i < 65; i += 16 )
        {
            const inputData = randomBytes(i);

            const encodeTx = await te.testSignedUnique(inputData);
            const encodeReceipt = await encodeTx.wait();
            const el = encodeReceipt!.logs[0] as EventLog;
            const encodedData = el.args[0];
            const expectedLength = el.args[1];

            // Expected length of encoded data matches actual encoded length
            expect(getBytes(encodedData).length).equal(expectedLength);

            const staticDecoded = await td.testSignedUnique.staticCall(encodedData);
            expect(staticDecoded).equal(hexlify(inputData));

            // Submit unique message on-chain
            const decodeTx = await td.testSignedUnique(encodedData);
            const decodeReceipt = await decodeTx.wait();
            const decodedDataFromEvent = (decodeReceipt!.logs[0] as EventLog).args[0];
            expect(decodedDataFromEvent).equal(hexlify(inputData));

            // Verify it can't be submitted again
            expect(td.testSignedUnique.staticCall(encodedData)).revertedWith("duplicate message");
        }
    });

    it('Signed Unique Message', async function () {
        this.timeout(LONGER_TIMEOUT);
        for( let i = 0; i < 65; i += 16 )
        {
            const inputSelector = randomBytes(4);
            const inputData = randomBytes(i);

            const encodeTx = await te.testSignedUniqueMessage(inputSelector, inputData);
            const encodeReceipt = await encodeTx.wait();
            const el = encodeReceipt!.logs[0] as EventLog;
            const encodedData = el.args[0];
            const expectedLength = el.args[1];

            // Expected length of encoded data matches actual encoded length
            expect(getBytes(encodedData).length).equal(expectedLength);

            const staticDecoded = await td.testSignedUniqueMessage.staticCall(encodedData);
            expect(staticDecoded.selector).equal(hexlify(inputSelector));
            expect(staticDecoded.data).equal(hexlify(inputData));

            // Submit unique message on-chain
            const decodeTx = await td.testSignedUniqueMessage(encodedData);
            const decodeReceipt = await decodeTx.wait();
            const decodedDataFromEvent = (decodeReceipt!.logs[0] as EventLog).args[0];
            expect(decodedDataFromEvent.selector).equal(hexlify(inputSelector));
            expect(decodedDataFromEvent.data).equal(hexlify(inputData));

            // Verify it can't be submitted again
            expect(td.testSignedUniqueMessage.staticCall(encodedData)).revertedWith("duplicate message");
        }
    });
});

describe('Unique Encoding & Decoding', () => {
    let tume: TestUniqueMessageEncoder;
    let tumd: TestUniqueMessageDecoder;

    before(async () => {
        const umef = await ethers.getContractFactory('TestUniqueMessageEncoder');
        tume = await umef.deploy();
        await tume.waitForDeployment();

        const umdf = await ethers.getContractFactory('TestUniqueMessageDecoder');
        tumd = await umdf.deploy();
        await tumd.waitForDeployment();
    });

    it('Unique Message', async function () {
        this.timeout(LONGER_TIMEOUT);
        for( let i = 0; i < 65; i += 16 )
        {
            const inputSelector = randomBytes(4);
            const inputData = randomBytes(i);

            const encodeTx = await tume.testUniqueMessage(inputSelector, inputData);
            const encodeReceipt = await encodeTx.wait();
            const el = encodeReceipt!.logs[0] as EventLog;
            const encodedData = el.args[0];
            const expectedLength = el.args[1];

            // Expected length of encoded data matches actual encoded length
            expect(getBytes(encodedData).length).equal(expectedLength);

            const staticDecoded = await tumd.testUniqueMessage.staticCall(encodedData);
            expect(staticDecoded.selector).equal(hexlify(inputSelector));
            expect(staticDecoded.data).equal(hexlify(inputData));

            // Submit unique message on-chain
            const decodeTx = await tumd.testUniqueMessage(encodedData);
            const decodeReceipt = await decodeTx.wait();
            const decodedDataFromEvent = (decodeReceipt!.logs[0] as EventLog).args[0];
            expect(decodedDataFromEvent.selector).equal(hexlify(inputSelector));
            expect(decodedDataFromEvent.data).equal(hexlify(inputData));

            // Verify it can't be submitted again
            expect(tumd.testUniqueMessage.staticCall(encodedData)).revertedWith("duplicate message");
        }
    });
});
