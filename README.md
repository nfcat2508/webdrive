## Getting started

You can run the project locally with the following steps:

1. Copy this repo via `git clone` or by downloading it
2. Copy the 'changeset_utils' repo via `git clone https://github.com/nfcat2508/changeset_utils.git` or by downloading it
3. Optional: Update the path in the file `.changeset_utils_path` within the projects directory with the actual path to `changeset_utils`
4. Have postgres database running locally accessible with username "postgres" and password: "postgres"
5. Run the `mix setup` Mix task from within the projects directory
6. Run the `mix phx.server` Mix task from within the projects directory
7. Open http://localhost:4000 and login with the following user:

| Email                    | Password     |
|:-------------------------|:-------------|
| user1@test.de&nbsp;&nbsp;| password4242 |

```bash
git clone https://github.com/nfcat2508/changeset_utils.git
git clone https://github.com/nfcat2508/webdrive.git
cd webdrive
mix setup
mix phx.server
```

## About the app
* users can upload files from their file system to the upload directory (which is /tmp when running with `mix phx.server`)
* the files can optionally be encrypted client-side to get end-to-end encryption
* the files can be shared by creating a password protected sharing link which can be shared with others
* other users can download a shared file by opening the sharing link. A registration is not required
* if a file was encrypted, users can opt to decrypt the file client-side or download the enctypted file as is.

## About the used technologies
* Phoenix Framework
* Phoenix LiveView
* OpenPGP.js
