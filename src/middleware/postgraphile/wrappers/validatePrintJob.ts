import { makeWrapResolversPlugin } from 'graphile-utils'

import { countPages } from '../../../lib/pdf'

export const ValidatePrintJobPlugin = makeWrapResolversPlugin({
    Mutation: {
        submitPrintJob: async (resolve, source, args, context, resolveInfo) => {
            const numPages: number = args.input.printConfig.numPages
            const filename: string = args.input.filename
            if (
                (await countPages(`upload/${context.userId}/${filename}`)) !==
                numPages
            ) {
                throw new Error(
                    "numPages didn't match the number of pages in the document"
                )
            }
            return resolve(source, args, context, resolveInfo)
        },
    },
})
