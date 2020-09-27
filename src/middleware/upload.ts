import multer, { diskStorage } from 'multer'
import { existsSync, mkdirSync } from 'fs'

const upload = multer({
    storage: diskStorage({
        destination: (req, __, cb) => {
            const dest = `upload/${req.auth?.firebaseUid}`
            const destExists = existsSync(dest)

            if (!destExists) {
                mkdirSync(dest)
            }
            cb(null, dest)
        },
        filename: (_, file, cb) => {
            cb(null, file.originalname)
        },
    }),
})

export default upload
