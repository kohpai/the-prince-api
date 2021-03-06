import { Request } from 'express'
import { postgraphile } from 'postgraphile'
import PgSimplifyInflectorPlugin from '@graphile-contrib/pg-simplify-inflector'

import config from '../../config'
import { ValidatePrintJobPlugin, ValidateTopUpPlugin } from './wrappers'
import { HealthCheckPlugin } from './extensions'

const pg = postgraphile(
    config.postgraphile.APP_CONN,
    config.postgraphile.SCHEMA,
    {
        appendPlugins: [
            PgSimplifyInflectorPlugin,
            ValidateTopUpPlugin,
            ValidatePrintJobPlugin,
            HealthCheckPlugin,
        ],
        graphiql: true,
        enhanceGraphiql: true,
        pgSettings: async (req: Request) => ({
            role: req.auth?.role,
            'jwt.claims.firebase_uid': `${req.auth?.firebaseUid}`,
            'price_config.black_cpp': req.priceConfig?.blackCpp,
            'price_config.color_cpp': req.priceConfig?.colorCpp,
            'price_config.discount_ratio': req.priceConfig?.discountRatio,
        }),
        additionalGraphQLContextFromRequest: async (req, _) => ({
            userId: req.auth?.firebaseUid,
        }),
    }
)

export default pg
