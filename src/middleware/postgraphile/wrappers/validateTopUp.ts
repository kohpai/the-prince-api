import { makeWrapResolversPlugin } from 'graphile-utils'

import config from '../../../config'

interface Input {
    orderId: string
    amount: number
}

const paypal = require('@paypal/checkout-server-sdk')
const paypalEnv =
    process.env.NODE_ENV === 'production'
        ? new paypal.core.LiveEnvironment(
              config.paypal.CLIENT_ID,
              config.paypal.CLIENT_SECRET
          )
        : new paypal.core.SandboxEnvironment(
              config.paypal.CLIENT_ID,
              config.paypal.CLIENT_SECRET
          )
const paypalClient = new paypal.core.PayPalHttpClient(paypalEnv)

function createCaptureRequest(orderId: string) {
    const request = new paypal.orders.OrdersCaptureRequest(orderId)
    request.requestBody({})
    return request
}

export const ValidateTopUpPlugin = makeWrapResolversPlugin({
    Mutation: {
        topUp: async (resolve, source, args, context, resolveInfo) => {
            const { orderId, amount }: Input = args.input

            if (amount < 5) {
                throw new Error('Invalid amount, expected more than 5,00 EUR')
            }

            const request = createCaptureRequest(orderId)

            let capturedAmount: number
            try {
                const capture = await paypalClient.execute(request)
                capturedAmount = parseFloat(
                    capture.result.purchase_units[0].payments.captures[0].amount
                        .value
                )
            } catch ({ _originalError: err }) {
                throw new Error(
                    `PayPal error {${err.statusCode}: ${err.text || '<None>'}}`
                )
            }

            if (capturedAmount !== amount) {
                throw new Error(
                    "Payment error: captured amount and received amount didn't match"
                )
            }

            return resolve(source, args, context, resolveInfo)
        },
    },
})
