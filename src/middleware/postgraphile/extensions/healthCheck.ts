import { makeExtendSchemaPlugin, gql } from 'graphile-utils'
import usb from 'usb'

interface HealthStats {
    printerConnected: boolean
    welcome: boolean
}

const typeDefs = gql`
    type HealthStats {
        printerConnected: Boolean
        welcome: Boolean
    }

    extend type Query {
        healthStats: HealthStats
    }
`

export const HealthCheckPlugin = makeExtendSchemaPlugin(() => {
    return {
        typeDefs,
        resolvers: {
            Query: {
                healthStats(): HealthStats {
                    const printerConnected = Boolean(usb.findByIds(1008, 57617))
                    const now = new Date().getHours()
                    const welcome = now > 6 && now < 23 // after 6 AM and before 11 PM
                    return {
                        printerConnected,
                        welcome,
                    }
                },
            },
        },
    }
})
