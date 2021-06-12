const pdfjs = require('pdfjs-dist/legacy/build/pdf')

export async function countPages(path: string): Promise<number> {
    return pdfjs
        .getDocument(path)
        .promise.then((pdf: any) => pdf.numPages) as number
}
