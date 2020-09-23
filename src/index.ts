import * as dotenv from 'dotenv'
dotenv.config()

import express, { Request } from 'express'
import * as https from 'https'
import { readFileSync } from 'fs'
import { postgraphile } from 'postgraphile'
// import { run } from 'graphile-worker'

// import taskList from './tasks'
import { checkAuth } from './auth'
import config from './config'

const app = express()
const key = readFileSync('./creds/key.pem')
const cert = readFileSync('./creds/cert.pem')

app.use('/graphql', checkAuth)

app.use(
    postgraphile(config.postgraphile.APP_CONN, config.postgraphile.SCHEMA, {
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
