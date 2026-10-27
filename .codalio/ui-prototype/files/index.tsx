import { StrictMode } from "react"
import * as ReactDOMClient from "react-dom/client"
import App from "./App"

const el = document.getElementById("root")
if (!el) {
  throw new Error("root element not found")
}
const root = ReactDOMClient.createRoot(el)
root.render(
  <StrictMode>
    <App />
  </StrictMode>
)
