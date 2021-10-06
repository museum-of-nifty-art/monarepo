<script>
  // TODO improve paths so they don't have to be relative, but declarative
  import nftImg1 from '../assets/cpunk-mock-nft.jpg'
  import nftImg2 from '../assets/bape-mock-nft.jpg'
  import nftImg3 from '../assets/mona-mock-nft.jpg'

const nftImgs = [
  nftImg1
  , nftImg2
  , nftImg3
]
</script>

<div class="card row-span-3 shadow-lg compact space-y-20 bg-base-100">
  <figure>
    <img style="max-height: 452px" src={nftImgs[Math.random()*3 | 0]} alt='nft' />
  </figure>
  <div class="flex-row items-center space-x-4 card-body">
    <div class="space-y-2">
      <h2 class="card-title">
        NFT Name
      </h2>
      <p class="text-base-content text-opacity-40">Collection: 0xDeaDbeEfDeaDbeEfDeaDbeEfDeaDbeEfDeaDbeEf</p>
      <span class="font-mono text-xl countdown">
        <span style="--value:23;"></span>h
        <span style="--value:59;"></span>m
        <span style="--value:59;"></span>s
      </span>
      <button class='btn btn-primary place-self-center w-full'>React</button>
    </div>
  </div>
</div>

