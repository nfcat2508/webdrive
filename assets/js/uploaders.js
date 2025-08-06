import * as openpgp from "../vendor/openpgp.min.mjs"
import {Socket} from "phoenix"

let Uploaders = {}

Uploaders.UpEnc = function(entries, _onViewError, resp, _liveSocket){
  let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  let socket = new Socket("/socket", {params: {token: csrfToken}})
  socket.connect()

  entries.forEach(entry => {
    let entryUploader = new EntryUploader(entry, resp.config, socket);
    entryUploader.upload();
})}

var EntryUploader = class {
    constructor(entry, config, socket) {
      let {chunk_size, chunk_timeout} = config
      this.entry = entry
      this.offset = 0
      this.chunkSize = chunk_size
      this.chunkTimeout = chunk_timeout
      this.chunkTimer = null
      this.errored = false
      this.uploadChannel = socket.channel(`up:${entry.ref}`, {token: entry.metadata().token})
    }

    error(reason) {
      console.log(`error occurred: ${reason}`)
      if(this.errored){ return }
      this.uploadChannel.leave()
      this.errored = true
      clearTimeout(this.chunkTimer)
      this.entry.error(reason)
    }

    upload() {
        this.uploadChannel.onError(reason => this.error(reason))
        this.uploadChannel.join()
          .receive("ok", _data => this.chunkedUpload())
          .receive("error", reason => console.log("Unable to join", reason))
   }

   async chunkedUpload(){
     const stream = await this.getStreamToUpload()
     const reader = stream.getReader()
     const uploader = this
     reader.read().then(async function processChunk({ done, value }) {
       if (done) {
         console.log("Stream complete")
         uploader.finish()
         return
       }
      const chunk = value
      uploader.offset += chunk.length
      const buffer = await new Blob([chunk]).arrayBuffer()
      if(!uploader.uploadChannel.isJoined()){
       console.log("Channel not joined!!!")
       return
     }
     return uploader.uploadChannel.push("chunk", buffer, uploader.chunkTimeout)
        .receive("ok", () => {
          uploader.entry.progress(uploader.calcProgress())
          return reader.read().then(processChunk)
        })
        .receive("error", ({reason}) => this.error(reason))
        .receive("timeout", () => console.log("timed out pushing"))
  })
}

   async getStreamToUpload(){
     const pass = sessionStorage.getItem("pass")
     if (pass === null) {
       return this.entry.file.stream()
     } else {
       const message = await openpgp.createMessage({ binary: this.entry.file.stream() })
       return await openpgp.encrypt({
          message, // input as Message object
          passwords: [pass], // multiple passwords possible
          format: 'binary' // don't ASCII armor (for Uint8Array output)
          })
     }
   }

   finish() {
     if(!this.uploadChannel.isJoined()){
       console.log("Channel not joined!!!")
       return
     }

     this.uploadChannel.push("finished")
     .receive("ok", () => {
       this.entry.progress(100)
     })
     .receive("error", ({reason}) => this.error(reason))
     .receive("timeout", () => console.log("timed out finishing"))
   }

   calcProgress() {
     return Math.min((this.offset / this.entry.file.size) * 100, 97)
   }
  };

export default Uploaders;
