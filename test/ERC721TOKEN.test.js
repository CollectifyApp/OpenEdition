const { deployContract, getBlockTimestamp, offsettedIndex } = require('./helpers.js');
const { expect } = require('chai');
const { BigNumber, utils } = require('ethers');

const RECEIVER_MAGIC_VALUE = '0x150b7a02';

const createTestSuite = ({ contract, constructorArgs }) =>
  function () {
    let offsetted;

    context(`${contract}`, function () {
      beforeEach(async function () {
        const [owner, addr1] = await ethers.getSigners();
        this.owner = owner
        this.addr1 = addr1

        this.erc721Token = await deployContract(contract, constructorArgs);

        // this.receiver = await deployContract('ERC721ReceiverMock', [RECEIVER_MAGIC_VALUE, this.erc721Token.address]);
        this.startTokenId = this.erc721Token.startTokenId ? (await this.erc721Token.startTokenId()).toNumber() : 0;

        offsetted = (...arr) => offsettedIndex(this.startTokenId, arr);
      });

      describe('supports interface specs', async function () {
        it('supports ERC165', async function () {
          expect(await this.erc721Token.supportsInterface('0x01ffc9a7')).to.eq(true);
        });

        it('supports IERC721', async function () {
          expect(await this.erc721Token.supportsInterface('0x80ac58cd')).to.eq(true);
        });

        it('supports ERC721Metadata', async function () {
          expect(await this.erc721Token.supportsInterface('0x5b5e139f')).to.eq(true);
        });

        it('supports ERC2981', async function () {
          expect(await this.erc721Token.supportsInterface('0x2a55205a')).to.eq(true);
        });

        it('does not support ERC721Enumerable', async function () {
          expect(await this.erc721Token.supportsInterface('0x780e9d63')).to.eq(true);
        });

        it('does not support random interface', async function () {
          expect(await this.erc721Token.supportsInterface('0x00000042')).to.eq(false);
        });
      });

      context('init create contract', async function() {
        it('mint price should be setted', async function () {
          expect(await this.erc721Token.mintPrice()).to.eq(constructorArgs[2]);
        })

        it('max supply should be setted', async function () {
          expect(await this.erc721Token.maxSupply()).to.eq(constructorArgs[3]);
        })

        it('max mint per address shoud be setted', async function () {
          expect(await this.erc721Token.maxCountPerAddress()).to.eq(constructorArgs[4]);
        })

        it('baseURI should be setted', async function () {
          expect(await this.erc721Token.baseURI()).to.eq(constructorArgs[5]);
        })

        // it('defaultrole should be setted', async function () {
        //   expect(await this.erc721Token.hasRole('0x0000000000000000000000000000000000000000000000000000000000000000', this.owner.address)).to.eq(true);
        //   expect(await this.erc721Token.hasRole('0x0000000000000000000000000000000000000000000000000000000000000000', this.addr1.address)).to.eq(false);
        //   expect(await this.erc721Token.hasRole('0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e', this.owner.address)).to.eq(true);
        //   expect(await this.erc721Token.hasRole('0xb19546dff01e856fb3f010c267a7b1c60363cf8a4664e21cc89c26224620214e', this.addr1.address)).to.eq(false);
        // })


        it('royalty fraction should be setted', async function () {
          const initInfo = await this.erc721Token.royaltyInfo(0, 100);
          expect(initInfo[0]).to.be.equal(this.owner.address);
          expect(initInfo[1]).to.be.equal(BigNumber.from('2'));
        })

        it('merkle root should be null', async function () {
          expect(await this.erc721Token.merkleRoot()).to.be.equal('0x0000000000000000000000000000000000000000000000000000000000000000');
        })

        it('timeZone should be setted', async function () {
          timezone = await this.erc721Token.timeZone();
          expect(timezone[0]).to.be.equal(constructorArgs[7][0]);
          expect(timezone[1]).to.be.equal(constructorArgs[7][1]);
        })

      })

      context('with no minted tokens', async function () {
        it('has 0 totalSupply', async function () {
          const supply = await this.erc721Token.totalSupply();
          expect(supply).to.equal(0);
        });

        it('_nextTokenId must be equal to _startTokenId', async function () {
          const _privateMintCount = await this.erc721Token._privateMintCount();
          expect(_privateMintCount).to.equal(0);
        });

        it('user minted function will work', async function () {
          const [owner] = await ethers.getSigners();
          this.owner = owner

          const minted = await this.erc721Token.isMinted(this.owner.address);
          expect(minted[0]).to.equal(false);
          expect(minted[1]).to.equal(false);
        })
      });

      context('set mint time', async function () {

        it('mint time should be setted', async function () {
          const timestamp = await getBlockTimestamp()
          this.erc721Token.changePrivateMintTime([timestamp, timestamp + 100]);
          this.erc721Token.changePublicMintTime([timestamp + 100, timestamp + 200]);
          const privateMintTime = await this.erc721Token.privateMintTime();
          expect(parseInt(privateMintTime[0])).to.equal(timestamp);
          expect(parseInt(privateMintTime[1])).to.equal(timestamp + 100);
          const publicMintTime = await this.erc721Token.publicMintTime();
          expect(parseInt(publicMintTime[0])).to.equal(timestamp + 100);
          expect(parseInt(publicMintTime[1])).to.equal(timestamp + 200);
        })

        it('Only the owner can modify it', async function () {
          const timestamp = await getBlockTimestamp()
          await expect(this.erc721Token.connect(this.addr1).changePrivateMintTime([timestamp, timestamp + 100])).to.be.revertedWith('Ownable: caller is not the owner');
          await expect(this.erc721Token.connect(this.addr1).changePublicMintTime([timestamp + 100, timestamp + 200])).to.be.revertedWith('Ownable: caller is not the owner');
        })
      })

    });
  };


// describe('ERC721A', createTestSuite({ contract: 'ERC721AMock', constructorArgs: ['Azuki', 'AZUKI'] }));
describe('ERC721TOKEN', createTestSuite({ contract: 'ERC721TOKEN', constructorArgs: ['ERC721TOKEN', 'token', utils.parseEther('0.1'), 100, 2, '', 200, [0, 'TEST'], [0, Math.round(Date.now() / 1000 + 3600)], [0, Math.round(Date.now() / 1000 + 3600)]] }));
