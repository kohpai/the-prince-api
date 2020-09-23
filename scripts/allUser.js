const admin = require('firebase-admin')

const serviceAccount = require('./firebase-service-account.json')

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://the-prince-98130.firebaseio.com',
})

const main = async () => {
    const users = await admin.auth().listUsers()
    console.log(users)
}

main()
