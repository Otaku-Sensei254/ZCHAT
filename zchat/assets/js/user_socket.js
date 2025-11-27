import { Socket } from "phoenix"

// Grab the user token from the DOM
const body = document.querySelector("body")
const token = body.dataset.token

let socket

// Only connect to the socket if a token is found.
if (token) {
  // Initialize Phoenix Socket
  socket = new Socket("/socket", { params: { token: token } })

  // Connect to the socket
  socket.connect()

  console.log("User socket connected.")
} else {
  console.log("No user token found, socket not connected.")
}

// Example of joining a channel (you can adapt this part)
// let channel = socket.channel("conversation:42", {})
// channel.join()
//   .receive("ok", resp => console.log("Joined conversation:42", resp))
//   .receive("error", resp => console.error("Unable to join", resp))

export default socket
