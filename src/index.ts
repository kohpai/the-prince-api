import * as dotenv from 'dotenv'
dotenv.config()

import express, { Request } from 'express'
import https from 'https'
import { readFileSync } from 'fs'
import cors from 'cors'
import { postgraphile } from 'postgraphile'
// import { run } from 'graphile-worker'

// import taskList from './tasks'
import { checkAuth } from './auth'
import upload from './upload'
import config from './config'
import ValidateTopUpPlugin from './wrappers/validateTopUp'

const pdfjs = require('pdfjs-dist/es5/build/pdf')

const app = express()
const key = readFileSync('./creds/key.pem')
const cert = readFileSync('./creds/cert.pem')

app.use(
    cors({
        origin: [
            'http://localhost:3000',
            'https://the-prince-98130.web.app',
            'https://the-prince-98130.firebaseapp.com',
        ],
    })
)
app.use(checkAuth)
app.use(
    postgraphile(config.postgraphile.APP_CONN, config.postgraphile.SCHEMA, {
        appendPlugins: [ValidateTopUpPlugin],
        graphiql: true,
        enhanceGraphiql: true,
        watchPg: true,
        ownerConnectionString: config.postgraphile.OWNER_CONN,
        pgSettings: async (req: Request) => ({
            role: req.auth?.role,
            'jwt.claims.firebase_uid': `${req.auth?.firebaseUid}`,
        }),
    })
)

app.post('/upload', upload.single('file'), async (req, res) => {
    const numPages = await pdfjs
        .getDocument(`upload/${req.auth?.firebaseUid}/${req.file.originalname}`)
        .promise.then((pdf: any) => pdf.numPages)
    res.status(200).json({ numPages })
})

https.createServer({ key, cert }, app).listen(+config.server.PORT, () => {
    console.log(`Server running at https://localhost:${config.server.PORT}`)
})

// run({
//     connectionString: connStr,
//     concurrency: 5,
//     noHandleSignals: false,
//     pollInterval: 1000,
//     taskList,
// })
