// Cloudflare Worker — serve the BrineStudios installer from your own URL.
//
// Deploy: Workers & Pages -> Create Worker -> paste this -> Deploy.
// Then add a route/custom domain, e.g.  install.example.com/*  or a path
// like  example.com/brinestudios*  and run:
//
//     bash <(curl -s https://install.example.com)
//
const UPSTREAM =
  "https://raw.githubusercontent.com/brineajay-94/Hosting-Website/main/install.sh";

export default {
  async fetch() {
    const res = await fetch(UPSTREAM, {
      cf: { cacheTtl: 300, cacheEverything: true },
    });
    return new Response(res.body, {
      status: res.status,
      headers: {
        "content-type": "text/plain; charset=utf-8",
        "cache-control": "public, max-age=300",
      },
    });
  },
};
