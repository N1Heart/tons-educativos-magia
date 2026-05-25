# res://base_test.gd
extends GdUnitTestSuite

const SERVER_KEY = "defaultkey"
const HOST = "127.0.0.1"
const PORT = 7350
const SCHEME = "http"

var client: NakamaClient
var session: NakamaSession

func before() -> void:
    client = Nakama.create_client(SERVER_KEY, HOST, PORT, SCHEME)

func after() -> void:
    client = null
    session = null