const { expect } = require('chai')
const { ethers } = require('hardhat')

describe('Exhibit', function () {
  let exhibit
    , erc721
    , erc20usd
    , owner
    , user = []
  before(async () => {
    user = await ethers.getSigners()
    owner = user[0]

    // deploy exhibit contract
    const ExhibitFactory = await ethers.getContractFactory('Exhibit')
    exhibit = await ExhibitFactory.deploy()
    await exhibit.deployed()

    // deploy sample erc721 contract
    const ERC721SampleNFT = await ethers.getContractFactory('ERC721SampleNFT')
    erc721 = await ERC721SampleNFT.deploy()
    await erc721.deployed()
    // mint NFTs to match user idx, user 2 owns NFT 2 and so on
    await erc721.mint(owner.address)
    await erc721.mint(user[1].address)
    await erc721.mint(user[2].address)

    const ERC20MockUSD = await ethers.getContractFactory('ERC20MockUSD')
    erc20usd = await ERC20MockUSD.deploy()
    await erc20usd.deployed()
    await erc20usd.mint(user[1].address, 5000 * 1e6)
    await erc20usd.mint(user[3].address, 1e5 * 1e6)
  })
  describe('listNFT(address _contractAddressNFT, uint256 _tokenIdNFT, uint64 _duration)', () => {
    it('should revert on user1 trying to list user2\'s NFT', async function () {
      await expect(exhibit.connect(user[1]).listNFT(
        erc721.address
        , 2
        , 86400
      )).to.be.revertedWith('Sender is not the owner of the NFT')
    })
    it('should list NFT for 1 day for user1\'s NFT & emit ListingNFT', async function () {
      await expect(exhibit.connect(user[1]).listNFT(
        erc721.address
        , 1
        , 86400
      )).to.emit(exhibit, 'ListingNFT')
      // TODO capture args before prod
      //.withArgs()
    })
    it('should list NFT for 30 days for user2\'s NFT & emit ListingNFT', async function () {
      await expect(exhibit.connect(user[2]).listNFT(
        erc721.address
        , 2
        , 86400*30
      )).to.emit(exhibit, 'ListingNFT')
      // TODO capture args before prod
      //.withArgs()
    })
    it('should revert on user1 trying to re-list the same NFT before expiry', async function () {
      await expect(exhibit.connect(user[1]).listNFT(
        erc721.address
        , 1
        , 86400
      )).to.be.reverted
    })
  })
  describe('getApproveTokenCalldata', () => {
    it('should get expected calldata for erc20 approval', async function () {
      let expected =
        `0x095ea7b3${'0'.repeat(24)}`
      expected += exhibit.address.substr(2).toLowerCase()
      expected += 'f'.repeat(64)
      // maybe better having ethersjs build the calldata?

      const result = await exhibit.callStatic.getApproveTokenCalldata()
      expect(result).to.equal(expected)
    })
    it('should return true on erc20 approval with that calldata', async function () {
      const data = await exhibit.callStatic.getApproveTokenCalldata()
      const approval = await user[1].call({
        to: erc20usd.address,
        data
      })
      const [decodedApproval] = ethers.utils.defaultAbiCoder.decode(
        ['bool'],
        approval
      )

      expect(decodedApproval).to.be.true
    })
  })
  describe('bond', () => {
    let user1CurationId
    before(() => {
      user1CurationId = ethers.utils.solidityKeccak256(
        [
          'address'
          , 'address'
          , 'uint256'
        ],
        [
          user[1].address
          , erc721.address
          , 1
        ]
      )
    })

    it('needs erc20 token transfer approval', async () => {
      const approveCalldata = await exhibit.getApproveTokenCalldata()
      console.log(user[1].address)
      const tx = await user[1].sendTransaction({
        to: erc20usd.address
        , data: approveCalldata
      })
      console.log(await tx.wait())
      // see about capping emitted approval event

      // const t = await erc20usd.connect(user[1]).approve(
      //   exhibit.address
      //   , ethers.constants.MaxUint256
      // )
      // console.log(t)


    })
    it('should react', async () => {
      // TODO cap ERC20 events
      const tx = await exhibit.connect(user[1]).reactionBond(
        user1CurationId
        , erc20usd.address
        , 1000 * 1e6
        , 86400
      )
      const receipt = await tx.wait()
      console.log(receipt)
      //console.log(receipt.events?.filter(
      //    x => x.event === 'LOG_Bonded')
      //  [0].args
      //)
      console.log(receipt.events[2].args)
      console.log(receipt.events[2].args.points.toString())
    })
  })

  //expect(await greeter.greet()).to.equal("Hello, world!");

  //const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

  //// wait until the transaction is mined
  //await setGreetingTx.wait();

  //expect(await greeter.greet()).to.equal("Hola, mundo!");
})
