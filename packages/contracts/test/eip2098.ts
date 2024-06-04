import { ethers } from "hardhat";
import { expect } from "chai";
import { TestEIP2098 } from "../typechain-types";
import { Signature, SigningKey, computeAddress, getBytes, hexlify, randomBytes } from "ethers";

describe('EIP-2098', () =>
{
    let te: TestEIP2098;

    before(async () =>
    {
        const f = await ethers.getContractFactory('TestEIP2098');
        te = await f.deploy()
        await te.waitForDeployment();
    });

    it('Encode & Decode Round-Trip', async () =>
    {
        for( let i = 0; i < 10; i += 1 )
        {
            const entropy = randomBytes(32);
            const sk = new SigningKey(entropy);
            const digest = randomBytes(32);
            const sig = sk.sign(digest);
            const r = getBytes(sig.r);
            const s = getBytes(sig.s);
            const v = sig.v;

            const c = await te.encode_decode.staticCall({r, s, v});
            expect(c.r).equals(hexlify(r));
            expect(c.s).equals(hexlify(s));
            expect(c.v).equals(sig.yParity);
        }
    });

    it('Sign then Encode & Decode', async function ()
    {
        const network = await ethers.provider.getNetwork();
        if( network.chainId == 31337n ) {
            this.skip();
        }

        for( let i = 0; i < 10; i += 1 )
        {
            const entropy = randomBytes(32);
            const sk = new SigningKey(entropy);
            const digest = randomBytes(32);

            // Ask contract to sign, then encode & decode using EIP-2098
            const result = await te.sign_encode_decode(entropy, digest);
            const out_sig = result.out_sig;
            const out_encoded = result.out_encoded;
            const out_decoded = result.out_decoded;
            const out_address = result.out_address;
            const sig = Signature.from({
                r: out_decoded.r,
                s: out_decoded.s,
                yParity: Number(out_decoded.v) == 1 ? 1 : 0
            });

            // Verify it matches what we calculated locally
            expect(sig.yParityAndS).equal(out_encoded[1]);
            expect(sig.v).equal(out_sig.v);
            expect(sig.r).equal(out_decoded.r);
            expect(sig.s).equal(out_decoded.s);
            expect(sig.yParity).equal(out_decoded.v);

            // And that address calculation matches
            const recoveredAddress = SigningKey.recoverPublicKey(digest, sig);
            expect(recoveredAddress).equal(sk.publicKey);
            expect(computeAddress(sk)).equal(out_address);
        }
    })
});