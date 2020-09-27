import { countPages } from '../src/lib/pdf'

async function main() {
    const count = await countPages(
        'upload/N94YsPz7CHeCoJHUQpqyqJ0EXua2/2013_Book_AnIntroductionToStatisticalLea.pdf'
    )
    console.log(count)
}

main()
