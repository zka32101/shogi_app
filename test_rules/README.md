# Firestore rules tests

    cd test_rules && npm i
    npx -y firebase-tools@13 emulators:exec --only firestore --project demo-koki "node matching.rules.test.mjs ../firestore.rules"

(firebase-tools 14+ needs JDK 21; 13.x works with JDK 11.)
