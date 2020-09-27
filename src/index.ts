import * as dotenv from 'dotenv'
dotenv.config()

import express from 'express'
import { run } from 'graphile-worker'

import cors from './middleware/cors'
import auth from './middleware/auth'
import postgraphile from './middleware/postgraphile'
import upload from './middleware/upload'
import taskList from './tasks'
import config from './config'
import { countPages } from './lib/pdf'

const app = express()

app.use(cors)
app.use(auth)
app.use(postgraphile)

app.post('/upload', upload.single('file'), async (req, res) => {
    const numPages = await countPages(
        `upload/${req.auth?.firebaseUid}/${req.file.originalname}`
    )
    res.status(200).json({ numPages })
})

app.listen(+config.server.PORT, () => {
    console.log(`Server running at http://localhost:${config.server.PORT}`)
})

run({
    connectionString: config.postgraphile.OWNER_CONN,
    concurrency: 5,
    noHandleSignals: false,
    pollInterval: 1000,
    taskList,
})
