import { storeJson } from '../fileModels/store.json'
import { i18n } from '../i18n'
import { sdk } from '../sdk'

const { InputSpec, Value } = sdk

export const selectIndexerAction = sdk.Action.withInput(
  'select-indexer',

  async () => ({
    name: i18n('Select Indexer'),
    description: i18n('Choose which indexer Dojo looks addresses up in'),
    warning: null,
    allowedStatuses: 'any',
    group: i18n('Configuration'),
    visibility: 'enabled',
  }),

  InputSpec.of({
    indexer: Value.select({
      name: i18n('Indexer'),
      description: i18n('Choose which indexer Dojo looks addresses up in'),
      values: {
        fulcrum: i18n('Fulcrum — faster rescans, more disk'),
        electrs: i18n('Electrs — smaller index, slower rescans'),
      },
      default: 'fulcrum',
    }),
  }),

  async ({ effects }) =>
    storeJson.read((s) => ({ indexer: s.indexer })).const(effects),

  async ({ effects, input }) => storeJson.merge(effects, input),
)
