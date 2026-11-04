extends RefCounted
# Elenco original: personajes inventados para este juego (no pertenecen a ninguna marca).
# Cada partida se barajan y se reparten al azar entre los dos equipos.
# Para agregar uno nuevo: añádelo aquí y crea su aspecto en character.gd (función _params y _decorate).

const LIST := [
	{"id": "rana", "name": "Rana Rayo"},
	{"id": "gato", "name": "Gato Máscara"},
	{"id": "cocodrilo", "name": "Colmillo"},
	{"id": "pinguino", "name": "Pingüi Bufanda"},
	{"id": "robot", "name": "Robo Óxido"},
	{"id": "monstruo", "name": "Tres Ojos"},
	{"id": "fantasma", "name": "Fantasmita"},
	{"id": "alien", "name": "Alien Antena"},
	{"id": "papa", "name": "Papa Brava"},
	{"id": "hotdog", "name": "Salchipán"},
	{"id": "pina", "name": "Piña Picante"},
	{"id": "huevo", "name": "Huevo Frito"},
]
