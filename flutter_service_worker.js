'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "9300a825ef6bab119951b83d9da68ce7",
"assets/AssetManifest.bin.json": "c8c69e7c1feba5aa4d11725dd1c683cf",
"assets/assets/heroes/Airi.jpg": "b6d4a9528a6da3f504641d7d8c9d303d",
"assets/assets/heroes/Aleister.jpg": "786608f14b3a4a8f123abea370baba7b",
"assets/assets/heroes/Alice.jpg": "7b3fc2c7f1484a335c2893cb3048d29d",
"assets/assets/heroes/Allain.jpg": "79433577a129edf2b506495713a80ce2",
"assets/assets/heroes/Amily.jpg": "f90992d3c782594cdc9608a8f156dd96",
"assets/assets/heroes/Annette.jpg": "bb1170c6dfca04dcb7bf746c421747c5",
"assets/assets/heroes/Aoi.jpg": "22e22b3e73ad3752757fd0f0d4d662fd",
"assets/assets/heroes/Arduin.jpg": "e2719028b999f17d26a6e9d792ee0faf",
"assets/assets/heroes/Arthur.jpg": "c98e059848b3da9d6c9cb911e6e860c5",
"assets/assets/heroes/Arum.jpg": "64b5eba34a13a7d431e41be6e7136db4",
"assets/assets/heroes/Astrid.jpg": "16e6556511beebec5e51b53e7b34fc79",
"assets/assets/heroes/Aya.jpg": "3ecb4bb56e74ffe30a9e571bf3b5bff4",
"assets/assets/heroes/Azzen'Ka.jpg": "c327701481b3c40aa470b7fa25c15c83",
"assets/assets/heroes/Baldum.jpg": "6a3d3675f92b2c3b6de3110a4b00cb32",
"assets/assets/heroes/Bijan.jpg": "e75b09e301b83f6bb1b5a728016f9453",
"assets/assets/heroes/Billow.jpg": "f2dbd656bac82edd1675867919bed1e4",
"assets/assets/heroes/Biron.jpg": "00c1f7ee8c7b1040b721b14625d347f7",
"assets/assets/heroes/Bolt%2520Baron.jpg": "33f8c0c064a0b6d3f1c6f0e64fea4f25",
"assets/assets/heroes/Bonnie.jpg": "49946c90d5972cdaa9cc099d9f75a5a0",
"assets/assets/heroes/Bright.jpg": "4646a4fbbc5ed4c58595237ea93ea40a",
"assets/assets/heroes/Brunhilda.jpg": "b5602aa4ced189754d59b08664301236",
"assets/assets/heroes/Butterfly.jpg": "894501fbec45aeccb7ac3cee276efc75",
"assets/assets/heroes/Capheny.jpg": "b65efe588fbcc98cf8edddf4e3af9afe",
"assets/assets/heroes/Charlotte.jpg": "76916c99b524d0aea62be3263a7704eb",
"assets/assets/heroes/Chaugnar.jpg": "a1b237c7863590e1b437439e63c063e6",
"assets/assets/heroes/Cresht.jpg": "69606a771e5355ea73838d9c204eb3a7",
"assets/assets/heroes/D'Arcy.jpg": "716526aa3ccaec8fa4cdadd7ab7a0bb2",
"assets/assets/heroes/Dextra.jpg": "e937113e3ac22d223eaff138d72f6b80",
"assets/assets/heroes/Diaochan.jpg": "bbbb56ba2e8e912d2607cae7dfce3225",
"assets/assets/heroes/Dirak.jpg": "4a08dc69c1c0de1bcbe7266dd1bb7f3e",
"assets/assets/heroes/Dolia.jpg": "57f52b9b006f5a2e54af1a28001393f1",
"assets/assets/heroes/Eland'orr.jpg": "87d92f207ef03797cfd6ac6aacac8d23",
"assets/assets/heroes/Elsu.jpg": "baf0aa04022a70f0778a24d22e048e0e",
"assets/assets/heroes/Enzo.jpg": "8e3893a365897cbc21860cfc219a8c49",
"assets/assets/heroes/Erin.jpg": "b3dd42eacdb12370e3982a4e72b90447",
"assets/assets/heroes/Errol.jpg": "fc40c48b447af9cdd0735b36983dbc4d",
"assets/assets/heroes/Fennik.jpg": "dbb73a16f70f3e43ba9c136c13547859",
"assets/assets/heroes/Florentino.jpg": "794dfceffe968840d28837c55f009108",
"assets/assets/heroes/Gildur.jpg": "5f73bdb09d52b57d5d4dc3efb851283c",
"assets/assets/heroes/Grakk.jpg": "d665596236b9948fdbcff8d584d4f232",
"assets/assets/heroes/Hayate.jpg": "e26bdcb4666d7e888a8763022778d632",
"assets/assets/heroes/Heino.jpg": "1c90751ebf6c49a516993d0419f0ee72",
"assets/assets/heroes/Helen.jpg": "82916f2892701bc0241bfe2a72f6e9b5",
"assets/assets/heroes/Iggy.jpg": "da1470f956d6e608620a600545d329cf",
"assets/assets/heroes/Ignis.jpg": "8f076a872458ecb5e5d9e996dec2e04c",
"assets/assets/heroes/Ilumia.jpg": "bf641aaf14c7f638c8d6097911984d65",
"assets/assets/heroes/Ishar.jpg": "8fc49028880b3b5ef14a0caf853d2481",
"assets/assets/heroes/Jinnar.jpg": "b8863c25d1628ba14124fc5d49c22d5e",
"assets/assets/heroes/Kahlii.jpg": "9d4e45ccd2aa9cad787a06cf291c3910",
"assets/assets/heroes/Kaine.jpg": "21a934215259d8d325007fdb4bd8a2ca",
"assets/assets/heroes/Keera.jpg": "7edd1db9daa7e91914361c725f9f46f6",
"assets/assets/heroes/Kil'Groth.jpg": "bf8a5b6832ad3759d00aa519393e7bad",
"assets/assets/heroes/Kriknak.jpg": "54c85f9e1b055ad414ad599337bb65a8",
"assets/assets/heroes/Krixi.jpg": "1a2b66958e0f9d494d49188f3ed90ecf",
"assets/assets/heroes/Krizzix.jpg": "3d999300b311102eb6b74689a216b87f",
"assets/assets/heroes/Lauriel.jpg": "72d78311e5ccead1e07ca6f9e69b269c",
"assets/assets/heroes/Laville.jpg": "228f74cc09bed61c14b6feb679261f2b",
"assets/assets/heroes/Liliana.jpg": "1704bb6ac9e26399d124f0629f39f87f",
"assets/assets/heroes/Lindis.jpg": "4d243e7376b1ae1ba8c2e4dd416dbf91",
"assets/assets/heroes/Lorion.jpg": "2c9fca6f0a700d98fd385a50f9939988",
"assets/assets/heroes/Lu%2520Bu.jpg": "3306734ba2937343e085943277bca5c6",
"assets/assets/heroes/Lumburr.jpg": "aacbe04fb9b95fdbbf8db339277f1722",
"assets/assets/heroes/Maloch.jpg": "983163b5c0692c0df51de6d1811ab3bf",
"assets/assets/heroes/Marja.jpg": "b1d27b999a7baf52d97e8284184ff7cd",
"assets/assets/heroes/Mganga.jpg": "895da18e05f91a382ce85d5536b6df67",
"assets/assets/heroes/Mina.jpg": "37364ff7482490bd64f04f098827de73",
"assets/assets/heroes/Ming.jpg": "95abc9521e168eed6188edee31f46f38",
"assets/assets/heroes/Moren.jpg": "dc699bdeea736d5015a9714fa2ca34fd",
"assets/assets/heroes/Murad.jpg": "8d1201eaebcfb7ddc0236a37d1235137",
"assets/assets/heroes/Nakroth.jpg": "04474bfc8a17cff2db61c41dc95f76dd",
"assets/assets/heroes/Natalya.jpg": "c40406b2a26d6709f5026ee16dc41e10",
"assets/assets/heroes/Omega.jpg": "fb275ff5050538d62f32d09ed8252b74",
"assets/assets/heroes/Omen.jpg": "d72b146bfd689e2ba5a0801b5cb42b53",
"assets/assets/heroes/Paine.jpg": "e60256b20f139cfcc9298efb5a5167ac",
"assets/assets/heroes/Preyta.jpg": "f32cdc7977f5adb6e464cb4e74911f2c",
"assets/assets/heroes/Qi.jpg": "69316482977095d3eb2eb1d81cb8399f",
"assets/assets/heroes/Quillen.jpg": "3d193d5e4f625248c469e9db73919705",
"assets/assets/heroes/Raz.jpg": "1f1387c27f3e5406f2fa81c1c890d3a9",
"assets/assets/heroes/Riktor.jpg": "aa4d66def7477f1922d288ee965569b3",
"assets/assets/heroes/Rouie.jpg": "5a30d7d86145123b0778b17e3498b1f0",
"assets/assets/heroes/Rourke.jpg": "7b488fecd05b8555045e83603cb29f44",
"assets/assets/heroes/Roxie.jpg": "f445977daecd8b3df7b0006206ef41ec",
"assets/assets/heroes/Ryoma.jpg": "015146c1caad039771f08b55cbfb9f8c",
"assets/assets/heroes/Sephera.jpg": "873ad012bbb30570e4aab52020ff17de",
"assets/assets/heroes/Sinestrea.jpg": "518457d8462b3927abfc95c678ff5746",
"assets/assets/heroes/Skud.jpg": "403ed291e242ae9f9ac702b989bf334b",
"assets/assets/heroes/Slimz.jpg": "c0d60af35105f79cb3fa0f552195d7bd",
"assets/assets/heroes/Stuart.jpg": "b97b4a8653fa9f456646eebcd1b71927",
"assets/assets/heroes/Superman.jpg": "a7cff6bc41fa8680a76c7204f5270750",
"assets/assets/heroes/Taara.jpg": "14772044b11ffae4d8566dc07ca85fde",
"assets/assets/heroes/Tachi.jpg": "32da6f051c1bed9bf8dc70eb10f9545f",
"assets/assets/heroes/TeeMee.jpg": "33a10982ae645d67c8076f1424986d17",
"assets/assets/heroes/Teeri.jpg": "40574105e7ebf7ee42c7e05dd7621e20",
"assets/assets/heroes/Tel'Annas.jpg": "217785bfa28027b7577f3bcf2564b083",
"assets/assets/heroes/Thorne.jpg": "d29572d3a74cef14d7d85163fb2ab970",
"assets/assets/heroes/Toro.jpg": "82c1627d22bad41d5b464d90e3066490",
"assets/assets/heroes/Tulen.jpg": "84eaf1f05fb98f15cd308e88c53772c7",
"assets/assets/heroes/Valhein.jpg": "33a467d5d84abd0a48fac8e98ceba4bf",
"assets/assets/heroes/Veera.jpg": "705d251bd1932b9cf4f5968cc8759e0d",
"assets/assets/heroes/Veres.jpg": "4d714df6b65bc60b9e81eec2543ea82e",
"assets/assets/heroes/Violet.jpg": "0e56a8704f7fd2dba19ac709674c2409",
"assets/assets/heroes/Volkath.jpg": "11e7ed2d4285d0c5872ca381604a8fba",
"assets/assets/heroes/Wiro.jpg": "bc2c347ed5206e50851d8bb03c14cf9a",
"assets/assets/heroes/Wisp.jpg": "f54469ed13d73e3137a558539eb118e4",
"assets/assets/heroes/Wonder%2520Woman.jpg": "b0f832ed90b884b298394bb22d5e33ec",
"assets/assets/heroes/Wukong.jpg": "5ef98099376205529faefca838709ab1",
"assets/assets/heroes/Xeniel.jpg": "26c3d0bc4009323b714611c1b70b6d52",
"assets/assets/heroes/Y'bneth.jpg": "7e0f9d0b38405137183661259219c4cc",
"assets/assets/heroes/Yan.jpg": "5ac75d8d6ca166ca30a02f6ebc8c31fa",
"assets/assets/heroes/Yena.jpg": "742534a138d3a037b23923450c87e121",
"assets/assets/heroes/Yorn.jpg": "a58501dd09e95c1d2a2453988b08dc04",
"assets/assets/heroes/Yue.jpg": "4bce2ec8876e20aada3aae4619f3b70a",
"assets/assets/heroes/Zanis.jpg": "9135a553b8fb35188cf581f31ba95432",
"assets/assets/heroes/Zata.jpg": "8457940a306ac078f362121c457df64f",
"assets/assets/heroes/Zephys.jpg": "7d0f09d982d7f085612e0deecbcc1a6b",
"assets/assets/heroes/Zill.jpg": "ddc4f3d3cb7a4ac85731a90667a66387",
"assets/assets/heroes/Zip.jpg": "32ff6ba2501503b2620e07d87e3f27fe",
"assets/assets/heroes/Zuka.jpg": "66fbca5828da1978a378cd7dc5d5b57a",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "773370d666454472a8d0e27921c7ca23",
"assets/NOTICES": "c3b823a35c3905d11fca06b86be72134",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "3baa8d422098409be252d1236637e463",
"icons/Icon-152.png": "f6f547759ad092fee887a1888aebb969",
"icons/Icon-167.png": "72feb12fe227bfa21a2c3843dad1e051",
"icons/Icon-180.png": "5d84231dea57edd7e1662cf69921fafd",
"icons/Icon-192.png": "17da4793972bfcc8a2f0a75be4fd1fc8",
"icons/Icon-512.png": "a5cd0f93f786e2629c76b894e733b602",
"icons/Icon-maskable-192.png": "17da4793972bfcc8a2f0a75be4fd1fc8",
"icons/Icon-maskable-512.png": "a5cd0f93f786e2629c76b894e733b602",
"index.html": "dfeaee5c67fb3755bd5ef9813248d375",
"/": "dfeaee5c67fb3755bd5ef9813248d375",
"main.dart.js": "c7a963a34e1c532ebc8122cfc43cc327",
"manifest.json": "6b060a239f9262d76dfe8fe351404ac9",
"version.json": "94e792a6d11b9baeeb8e9f049a02f82b"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
