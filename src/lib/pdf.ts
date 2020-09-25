const pdfjs = require('pdfjs-dist/es5/build/pdf')

export async function countPages(path: string): Promise<number> {
    return pdfjs
        .getDocument(path)
        .promise.then((pdf: any) => pdf.numPages) as number
}
