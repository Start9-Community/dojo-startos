import { IMPOSSIBLE, VersionInfo } from '@start9labs/start-sdk'

export const current = VersionInfo.of({
  version: '1.29.2:7',
  releaseNotes: {
    en_US: 'The pairing code from View Pairing Code connects wallets over Tor.',
    es_ES:
      'El código de emparejamiento de View Pairing Code conecta las billeteras a través de Tor.',
    de_DE:
      'Der Kopplungscode aus View Pairing Code verbindet Wallets über Tor.',
    pl_PL: 'Kod parowania z View Pairing Code łączy portfele przez Tor.',
    fr_FR:
      "Le code d'appairage de View Pairing Code connecte les portefeuilles via Tor.",
  },
  migrations: {
    up: async () => {},
    down: IMPOSSIBLE,
  },
})
