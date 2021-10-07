<script>
  // TODO improve paths so they don't have to be relative, but declarative
  import nftImg1 from '../assets/cpunk-mock-nft.jpg'
  import nftImg2 from '../assets/bape-mock-nft.jpg'
  import nftImg3 from '../assets/mona-mock-nft.jpg'
  import { onDestroy } from 'svelte'

const nftImgs = [
  nftImg1
  , nftImg2
  , nftImg3
]
const linkBuilder = () =>
  'https://etherscan.io/address/0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef'

const initTime = () =>
  Math.random() > 0.75 ?
    Math.random() * 86400 * 5 + 300 | 0 :
    Math.random() * 3000 + 600 | 0

let countdown = initTime()
let s = countdown % 60

const interval =
  setInterval(() => countdown -= 1, 1000)

onDestroy(() =>
  clearInterval(interval)
)

$: s = countdown % 60 | 0
$: m = countdown / 60 % 60 | 0
$: h = countdown / (60 * 60)  % 24 | 0
$: d = countdown / (60 * 60 * 24) | 0

</script>

<div class="card m-4 lg:m-0 row-span-3 shadow-lg compact sm:space-y-20 bg-base-100">
  <div class="grid place-items-center sm:h-96 overflow-hidden mt-3 mx-3 sm:mt-9 sm:mx-9">
    <img class="sm:h-96 object-contain transform-gpu scale-110" src={nftImgs[Math.random()*3 | 0]} alt='nft' />
  </div>
  <div class="flex-row items-center space-x-4 card-body break-words">
    <div class="space-y-2 w-full">
      <h2 class="card-title">
        NFT Name
      </h2>
      <p class="text-base-content text-opacity-40 break-all">
        Collection:
        <br/>
        <a target="_blank" href={linkBuilder()} class="link link-secondary">
          0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF
        </a>
      </p>
      <span class="font-mono text-xl countdown">
        {#if d > 0}
          <span style="--value:{d};"></span>d
          <span style="--value:{h};"></span>h
          <span style="--value:{m};"></span>m
        {:else}
          <span style="--value:{h};"></span>h
          <span style="--value:{m};"></span>m
          <span style="--value:{s};"></span>s
        {/if}
      </span>
      <button class='btn btn-primary place-self-center w-full'>React</button>
    </div>
  </div>
</div>

