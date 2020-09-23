import * as dotenv from 'dotenv'
dotenv.config()

import * as admin from 'firebase-admin'

import config from '../src/config'

admin.initializeApp({
    credential: admin.credential.cert(
        JSON.parse(config.firebase.SERVICE_ACCOUNT) /*|| serviceAccount*/
    ),
    databaseURL: config.firebase.DATABASE_URL,
})

async function main() {
    const users = await admin.auth().listUsers()
    console.log(users)
}

main()
