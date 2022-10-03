import { execFileSync } from 'child_process'
import { Helpers } from 'graphile-worker'

type ColorMode = 'BLACK' | 'COLOR'

interface PrintConfig {
    colorMode: ColorMode
    pageRange?: string
    numCopies: number
}

interface PrintJob {
    id: string
    filepath: string
    printConfig: PrintConfig
}

function isInstanceOfPrintJob(object: any): object is PrintJob {
    const printConfig = object.printConfig || {}
    return (
        'id' in object &&
        'filepath' in object &&
        'colorMode' in printConfig &&
        'numCopies' in printConfig
    )
}

export async function printDoc(payload: unknown, helpers: Helpers) {
    if (!isInstanceOfPrintJob(payload)) {
        helpers.logger.error(
            `Wrong type of payload: \n${JSON.stringify(payload, undefined, 2)}`
        )
        return
    }

    const { id, filepath, printConfig } = payload
    const { colorMode, pageRange, numCopies } = printConfig

    let status: 'EXECUTED' | 'FAILED' = 'FAILED'
    try {
        execFileSync('lpoptions', [
            '-o',
            `ColorModel=${colorMode === 'BLACK' ? 'KGray' : 'RGB'}`,
        ])
        execFileSync(
            'lp',
            (pageRange ? ['-P', pageRange] : []).concat([
                '-n',
                `${numCopies}`,
                '-o',
                'fit-to-page',
                '-o',
                'media=A4',
                filepath,
            ])
        )

        status = 'EXECUTED'
        helpers.logger.info(`Print Job ID ${id} ${status}`)
    } catch (err) {
        status = 'FAILED'
        helpers.logger.error(`Print Job ID ${id} ${status}`)
    }

    helpers.withPgClient(async (pgClient) => {
        await pgClient.query(
            `UPDATE public.print_job SET status = '${status}' WHERE id = ${id}`
        )
        helpers.logger.info(`Print Job ID ${id} updated with status ${status}`)
    })
}
