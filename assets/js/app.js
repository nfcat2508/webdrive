// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

import Uploaders from "./uploaders"
import {
  decrypt as openpgpDecrypt,
  readMessage as  openpgpReadMessage,
} from "../vendor/openpgp.min.mjs"


let Hooks = {}
Hooks.Download = {
  url() { return this.el.dataset.url },
  name() { return this.el.dataset.name },
  size() { return this.el.dataset.size },
  passInputID() { return this.el.dataset.input_id },
  progressID() { return this.el.dataset.progress_id },

  getPassElem() {
    return document.getElementById(this.passInputID())
  },

  getProgressElem() {
    return document.getElementById(this.progressID())
  },

  noPass() {
    return this.getPassElem().value.trim().length == 0
  },

  resetInput() {
    this.getPassElem().value = ""
  },

  setup() {
    this.liveSocket.execJS(this.el, this.el.getAttribute("phx-setup"))
    this.el.setAttribute("disabled", "")
    this.progressElem = this.getProgressElem()
    this.progressElem.setAttribute("value", 0)
  },
  teardown() {
    this.liveSocket.execJS(this.el, this.el.getAttribute("phx-teardown"))
    this.el.removeAttribute("disabled")
  },
  error(reason) {
    console.log(`error occurred: ${reason}`)
    this.liveSocket.execJS(this.el, this.el.getAttribute("phx-error"))
  },
  toProgressStream(stream, size, onRead) {
    let read = 0
    const reader = stream.getReader()
    return new ReadableStream({
      async pull(controller) {
        const result = await reader.read()
        if (result.done) {
          controller.close()
        }
        read += result.value.byteLength
        controller.enqueue(result.value)
        onRead(read / size)
      }
    })
  },
  async decrypt(readableStream) {
    let pass = this.getPassElem().value
    return openpgpReadMessage({ binaryMessage: readableStream })
    .then(message => openpgpDecrypt({
      message: message, passwords: [pass],
      format: "binary",
      config: {allowUnauthenticatedStream: true}
    }))
    .then(decrypted => decrypted.data)
  },
  progress(progressValue) {
    this.progressElem.setAttribute("value", progressValue)
  },
  saveDialog(url) {
    const a = document.createElement('a')
    a.href = url
    a.download = this.name()
    a.click()
  },
  mounted() {
    this.el.addEventListener("click", e => {
      if (this.noPass()) {
        this.resetInput()
        return
      } else {
        this.setup()

        fetch(this.url())
        .then(response => response.body)
        .then(readableStream => this.decrypt(readableStream))
        .then(decrypted => this.toProgressStream(decrypted, this.size(), p => this.progress(p)))
        .then(progressStream => new Response(progressStream))
        .then(response => response.blob())
        .then(blob => URL.createObjectURL(blob))
        .then(url => this.saveDialog(url))
        .catch(error => this.error(error))
        .finally(() => this.teardown())
      }
    })
  }
}

Hooks.MaybePass = {
  mounted() {
    this.handleEvent("enter_pass", _ => {
      this.liveSocket.execJS(this.el, this.el.getAttribute("show-input"))
    })
    this.handleEvent("remove_pass", _ => {
      sessionStorage.removeItem("pass")
    })
  }
}

Hooks.FinishPass = {
  inputID() { return this.el.dataset.input_id },
  modalID() { return this.el.dataset.modal_id },

  mounted() {
    this.el.addEventListener("click", e => {
      pass_elem = document.getElementById(this.inputID())
      pass = pass_elem.value.trim()
      if (pass.length == 0) {
        pass_elem.value = ""
      } else {
        sessionStorage.setItem("pass", pass)
        this.pushEvent("has-pass", {})
        modal_el = document.getElementById(this.modalID())
        liveSocket.execJS(modal_el, modal_el.getAttribute("phx-remove"))
      }
    })
  }
}

Hooks.BlurOnEnter = {
    mounted() {
        this.el.addEventListener("keyup", event => {
            if (event.key === "Enter") {
                this.el.blur()
            }
        });
    }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, uploaders: Uploaders, hooks: Hooks})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

