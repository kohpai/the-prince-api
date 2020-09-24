import { makeWrapResolversPlugin } from 'graphile-utils'

import config from '../config'

const paypal = require('@paypal/checkout-server-sdk')

const paypalClient = new paypal.core.PayPalHttpClient(
    new paypal.core.SandboxEnvironment(
        config.paypal.CLIENT_ID,
        config.paypal.CLIENT_SECRET
    )
)

function createCaptureRequest(orderId: string) {
    const request = new paypal.orders.OrdersCaptureRequest(orderId)
    request.requestBody({})
    return request
}

export default makeWrapResolversPlugin({
    Mutation: {
        topUp: async (resolve, source, args, context, resolveInfo) => {
            const orderId: string = args.input.orderId
            const amount: number = args.input.amount

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
