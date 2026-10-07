# Local database

Momentum stores categories, tasks, events, AI plan records, and linked-account
records in a local SQLite database. On Web, the experimental
`sqflite_common_ffi_web` adapter stores the SQLite image in browser IndexedDB.
No sample linked-account credentials are created.

The first database creation inserts the sample categories, tasks, and events
once. Later launches use the saved records and do not restore deleted sample
items.

To run in a browser, generate the adapter's WebAssembly and worker assets after
`flutter pub get`, then use the same browser origin and port on each run:

```sh
dart run sqflite_common_ffi_web:setup
flutter run -d web-server --web-port 8080
```

IndexedDB is scoped to the origin, including its port. For example,
`localhost:8080` and `localhost:8081` use separate Momentum databases. Clearing
the browser's site data removes the local database.
