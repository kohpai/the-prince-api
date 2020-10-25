import admin, { remoteConfig } from '../lib/firebase'

import ExplicitParameterValue = admin.remoteConfig.ExplicitParameterValue

interface PriceConfig {
    blackCpp: string
    colorCpp: string
    discountRatio: string
}

const config = {
    postgraphile: {
        SCHEMA: process.env.POSTGRESQL_SCHEMA,
        APP_CONN: process.env.POSTGRAPHILE_APP_CONN,
        OWNER_CONN: process.env.POSTGRAPHILE_OWNER_CONN,
    },
    server: {
        PORT: process.env.PORT || 5000,
    },
    firebase: {
        SERVICE_ACCOUNT: process.env.FIREBASE_SERVICE_ACCOUNT || 'false',
        DATABASE_URL: process.env.FIREBASE_DATABASE_URL,
    },
    paypal: {
        CLIENT_ID: process.env.PAYPAL_CLIENT_ID,
        CLIENT_SECRET: process.env.PAYPAL_CLIENT_SECRET,
    },
}

let priceConfig: PriceConfig | null = null

export async function getPriceConfig() {
    if (!priceConfig) {
        const template = await remoteConfig.getTemplate()
        const parameters = template.parameters
        priceConfig = {
            blackCpp: (parameters['black_cpp']
                .defaultValue as ExplicitParameterValue).value,
            colorCpp: (parameters['color_cpp']
                .defaultValue as ExplicitParameterValue).value,
            discountRatio: `${
                parseInt(
                    (parameters['discount_percentage']
                        .defaultValue as ExplicitParameterValue).value
                ) / 100
            }`,
        }
    }
    return priceConfig
}

export default config
