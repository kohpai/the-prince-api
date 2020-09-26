import * as dotenv from 'dotenv'
dotenv.config()

import express, { Request } from 'express'
import cors from 'cors'
import { postgraphile } from 'postgraphile'
const PgSimplifyInflectorPlugin = require('@graphile-contrib/pg-simplify-inflector')
// import { run } from 'graphile-worker'

// import taskList from './tasks'
import { checkAuth } from './auth'
import upload from './upload'
import config from './config'
import { ValidatePrintJobPlugin, ValidateTopUpPlugin } from './wrappers'
import { countPages } from './lib/pdf'

const app = express()

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
        appendPlugins: [
            PgSimplifyInflectorPlugin,
            ValidateTopUpPlugin,
            ValidatePrintJobPlugin,
        ],
        graphiql: true,
        enhanceGraphiql: true,
        watchPg: true,
        ownerConnectionString: config.postgraphile.OWNER_CONN,
        pgSettings: async (req: Request) => ({
            role: req.auth?.role,
            'jwt.claims.firebase_uid': `${req.auth?.firebaseUid}`,
        }),
        additionalGraphQLContextFromRequest: async (req, _) => ({
            userId: req.auth?.firebaseUid,
        }),
    })
)

app.post('/upload', upload.single('file'), async (req, res) => {
    const numPages = await countPages(
        `upload/${req.auth?.firebaseUid}/${req.file.originalname}`
    )
    res.status(200).json({ numPages })
})

app.listen(+config.server.PORT, () => {
    console.log(`Server running at http://localhost:${config.server.PORT}`)
})

// run({
//     connectionString: connStr,
//     concurrency: 5,
//     noHandleSignals: false,
//     pollInterval: 1000,
//     taskList,
// })
