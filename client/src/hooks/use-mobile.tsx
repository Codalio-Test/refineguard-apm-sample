import * as React from "react"

const MOBILE_BREAKPOINT = 768

function isMobileViewport() {
  return typeof window !== "undefined" && window.innerWidth < MOBILE_BREAKPOINT
}

export function useIsMobile() {
  // Seeded from the viewport, then kept in sync with the media-query listener —
  // no synchronous setState inside the effect.
  const [isMobile, setIsMobile] = React.useState<boolean>(() => isMobileViewport())

  React.useEffect(() => {
    const mql = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
    const onChange = () => setIsMobile(mql.matches)
    mql.addEventListener("change", onChange)
    return () => mql.removeEventListener("change", onChange)
  }, [])

  return isMobile
}
