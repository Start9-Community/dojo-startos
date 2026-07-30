import { setupManifest } from '@start9labs/start-sdk'
import {
  bitcoinDescription,
  bitcoinTestnetDescription,
  electrsDescription,
  fulcrumDescription,
  long,
  short,
  torDescription,
} from './i18n'

export const manifest = setupManifest({
  id: 'dojo',
  title: 'Dojo',
  license: 'AGPL-3.0',
  packageRepo: 'https://github.com/Start9-Community/dojo-startos',
  upstreamRepo: 'https://github.com/Dojo-Open-Source-Project/samourai-dojo',
  marketingUrl: 'https://dojo-osp.org/',
  donationUrl: 'https://dojo-osp.org/donate/',
  description: { short, long },
  volumes: ['main', 'db'],
  images: {
    dojo: {
      source: { dockerBuild: { dockerfile: './Dockerfile', workdir: '.' } },
      arch: ['x86_64', 'aarch64'],
    },
  },
  dependencies: {
    bitcoind: {
      description: bitcoinDescription,
      optional: true,
      metadata: {
        title: 'Bitcoin',
        icon: 'https://raw.githubusercontent.com/Start9Labs/bitcoin-core-startos/refs/heads/31.x/dep-icon.svg',
      },
    },
    'bitcoind-testnet': {
      description: bitcoinTestnetDescription,
      optional: true,
      metadata: {
        title: 'Bitcoin (testnet4)',
        icon: 'https://raw.githubusercontent.com/remcoros/bitcoind-testnet4-startos/refs/heads/31.x-testnet4/dep-icon.svg',
      },
    },
    fulcrum: {
      description: fulcrumDescription,
      optional: true,
      metadata: {
        title: 'Fulcrum',
        icon: 'https://raw.githubusercontent.com/Start9Labs/fulcrum-startos/refs/heads/master/icon.png',
      },
    },
    electrs: {
      description: electrsDescription,
      optional: true,
      metadata: {
        title: 'Electrs',
        icon: 'https://raw.githubusercontent.com/Start9-Community/electrs-startos/refs/heads/master/icon.svg',
      },
    },
    tor: {
      description: torDescription,
      optional: false,
      metadata: {
        title: 'Tor',
        icon: 'https://raw.githubusercontent.com/Start9Labs/tor-startos/refs/heads/master/icon.svg',
      },
    },
  },
})
