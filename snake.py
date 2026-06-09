import pygame
import random
import sys
import json
import os

# ── Colours ──────────────────────────────────────────────────────────────────
BG          = (15,  15,  15)
GRID_LINE   = (30,  30,  30)
SNAKE_HEAD  = (0,   230, 80)
SNAKE_BODY  = (0,   180, 60)
SNAKE_OUT   = (0,   120, 40)
FOOD_COL    = (220, 50,  50)
GOLD_COL    = (255, 210, 0)
WALL_COL    = (80,  80,  100)
TEXT_COL    = (200, 200, 200)
HUD_BG      = (20,  20,  20)
FLASH_COL   = (0,   255, 120)

CELL        = 22          # pixel size of one grid cell
HUD_H       = 50          # height of the score bar on top

# ── Level definitions ─────────────────────────────────────────────────────────
#  cols, rows, fps, food_to_next_level, obstacles
LEVELS = [
    dict(cols=20, rows=15, fps=7,  next=3,  walls=0,  name="Level 1 – Beginner"),
    dict(cols=25, rows=18, fps=10, next=5,  walls=3,  name="Level 2 – Rookie"),
    dict(cols=30, rows=22, fps=13, next=7,  walls=6,  name="Level 3 – Skilled"),
    dict(cols=35, rows=25, fps=17, next=10, walls=9,  name="Level 4 – Expert"),
    dict(cols=40, rows=28, fps=22, next=999, walls=13, name="Level 5 – LEGEND"),
]

HIGHSCORE_FILE = os.path.join(os.path.dirname(__file__), "highscore.json")


def load_highscore():
    try:
        with open(HIGHSCORE_FILE) as f:
            return json.load(f).get("hs", 0)
    except Exception:
        return 0


def save_highscore(hs):
    with open(HIGHSCORE_FILE, "w") as f:
        json.dump({"hs": hs}, f)


# ── Helpers ───────────────────────────────────────────────────────────────────
def rand_cell(cols, rows, exclude):
    while True:
        c = (random.randint(0, cols - 1), random.randint(0, rows - 1))
        if c not in exclude:
            return c


def place_walls(cols, rows, n, snake):
    exclude = set(snake)
    walls = []
    while len(walls) < n:
        w = (random.randint(2, cols - 3), random.randint(2, rows - 3))
        if w not in exclude and w not in walls:
            walls.append(w)
            exclude.add(w)
    return walls


# ── Drawing ───────────────────────────────────────────────────────────────────
def cell_rect(col, row):
    return pygame.Rect(col * CELL, HUD_H + row * CELL, CELL, CELL)


def draw_grid(surf, cols, rows):
    for c in range(cols + 1):
        x = c * CELL
        pygame.draw.line(surf, GRID_LINE, (x, HUD_H), (x, HUD_H + rows * CELL))
    for r in range(rows + 1):
        y = HUD_H + r * CELL
        pygame.draw.line(surf, GRID_LINE, (0, y), (cols * CELL, y))


def draw_snake(surf, snake):
    for i, (c, r) in enumerate(snake):
        rect = cell_rect(c, r)
        inner = rect.inflate(-4, -4)
        if i == 0:
            pygame.draw.rect(surf, SNAKE_HEAD, rect, border_radius=6)
            # eyes
            eye_size = max(2, CELL // 7)
            pygame.draw.circle(surf, BG, rect.topleft + pygame.Vector2(CELL * 0.28, CELL * 0.28), eye_size)
            pygame.draw.circle(surf, BG, rect.topleft + pygame.Vector2(CELL * 0.72, CELL * 0.28), eye_size)
        else:
            pygame.draw.rect(surf, SNAKE_BODY, inner, border_radius=4)
            pygame.draw.rect(surf, SNAKE_OUT, inner, 1, border_radius=4)


def draw_food(surf, pos, gold=False):
    rect = cell_rect(*pos)
    colour = GOLD_COL if gold else FOOD_COL
    cx, cy = rect.centerx, rect.centery
    r = CELL // 2 - 3
    pygame.draw.circle(surf, colour, (cx, cy), r)
    pygame.draw.circle(surf, (255, 255, 255), (cx - r // 3, cy - r // 3), max(2, r // 4))


def draw_walls(surf, walls):
    for c, r in walls:
        rect = cell_rect(c, r)
        pygame.draw.rect(surf, WALL_COL, rect.inflate(-2, -2), border_radius=3)


def draw_hud(surf, score, highscore, level_name, cols, fps, paused):
    pygame.draw.rect(surf, HUD_BG, (0, 0, cols * CELL, HUD_H))
    font_sm = pygame.font.SysFont("consolas", 15, bold=True)
    font_md = pygame.font.SysFont("consolas", 18, bold=True)
    surf.blit(font_md.render(f"SCORE  {score:04d}", True, SNAKE_HEAD), (8, 8))
    surf.blit(font_sm.render(f"BEST {highscore:04d}", True, TEXT_COL), (8, 30))
    name_surf = font_sm.render(level_name, True, GOLD_COL)
    surf.blit(name_surf, (cols * CELL // 2 - name_surf.get_width() // 2, 17))
    fps_surf = font_sm.render(f"{fps} FPS", True, GRID_LINE)
    surf.blit(fps_surf, (cols * CELL - fps_surf.get_width() - 8, 17))
    if paused:
        p = font_md.render("⏸  PAUSED", True, GOLD_COL)
        surf.blit(p, (cols * CELL - p.get_width() - 8, 4))


def draw_overlay(surf, lines, cols, rows):
    overlay = pygame.Surface((cols * CELL, rows * CELL + HUD_H), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 160))
    surf.blit(overlay, (0, 0))
    fonts = [
        pygame.font.SysFont("consolas", 36, bold=True),
        pygame.font.SysFont("consolas", 20),
        pygame.font.SysFont("consolas", 16),
    ]
    total_h = sum(fonts[min(i, len(fonts) - 1)].get_height() + 10 for i in range(len(lines)))
    y = (rows * CELL + HUD_H) // 2 - total_h // 2
    for i, (text, fi, colour) in enumerate(lines):
        f = fonts[min(fi, len(fonts) - 1)]
        s = f.render(text, True, colour)
        surf.blit(s, (cols * CELL // 2 - s.get_width() // 2, y))
        y += s.get_height() + 10


def flash_screen(surf, cols, rows, colour, frames=6):
    overlay = pygame.Surface((cols * CELL, rows * CELL + HUD_H))
    overlay.set_alpha(120)
    overlay.fill(colour)
    surf.blit(overlay, (0, 0))


# ── Game state ────────────────────────────────────────────────────────────────
class Game:
    def __init__(self, level_idx=0):
        self.level_idx  = level_idx
        self.lv         = LEVELS[level_idx]
        self.cols       = self.lv["cols"]
        self.rows       = self.lv["rows"]
        self.score      = 0
        self.food_eaten = 0
        self.flash      = 0

        cx, cy = self.cols // 2, self.rows // 2
        self.snake  = [(cx, cy), (cx - 1, cy), (cx - 2, cy)]
        self.dir    = (1, 0)
        self.next_d = (1, 0)
        self.alive  = True
        self.won    = False

        self.walls  = place_walls(self.cols, self.rows, self.lv["walls"], self.snake)
        occupied    = set(self.snake) | set(self.walls)
        self.food   = rand_cell(self.cols, self.rows, occupied)
        self.gold   = None
        self.gold_timer = 0
        self._maybe_spawn_gold()

    def _maybe_spawn_gold(self):
        if self.gold is None and random.random() < 0.15:
            occupied = set(self.snake) | set(self.walls) | {self.food}
            self.gold = rand_cell(self.cols, self.rows, occupied)
            self.gold_timer = 60 + random.randint(0, 30)

    def handle_key(self, key):
        dirs = {
            pygame.K_UP:    (0, -1), pygame.K_w: (0, -1),
            pygame.K_DOWN:  (0,  1), pygame.K_s: (0,  1),
            pygame.K_LEFT:  (-1, 0), pygame.K_a: (-1, 0),
            pygame.K_RIGHT: (1,  0), pygame.K_d: (1,  0),
        }
        if key in dirs:
            nd = dirs[key]
            if (nd[0] != -self.dir[0]) or (nd[1] != -self.dir[1]):
                self.next_d = nd

    def step(self):
        if not self.alive:
            return
        self.dir = self.next_d
        head = (self.snake[0][0] + self.dir[0],
                self.snake[0][1] + self.dir[1])

        # wall collision (border)
        if not (0 <= head[0] < self.cols and 0 <= head[1] < self.rows):
            self.alive = False
            return
        # obstacle collision
        if head in self.walls:
            self.alive = False
            return
        # self collision
        if head in self.snake[:-1]:
            self.alive = False
            return

        self.snake.insert(0, head)
        grew = False

        # eat normal food
        if head == self.food:
            self.score += 1
            self.food_eaten += 1
            grew = True
            self.flash = 4
            occupied = set(self.snake) | set(self.walls)
            if self.gold:
                occupied.add(self.gold)
            self.food = rand_cell(self.cols, self.rows, occupied)
            self._maybe_spawn_gold()

        # eat golden food
        elif head == self.gold:
            self.score += 3
            self.food_eaten += 3
            grew = True
            self.flash = 8
            self.gold = None

        if not grew:
            self.snake.pop()

        # golden food timer
        if self.gold:
            self.gold_timer -= 1
            if self.gold_timer <= 0:
                self.gold = None

        # check level-up
        if self.food_eaten >= self.lv["next"]:
            if self.level_idx < len(LEVELS) - 1:
                return "LEVELUP"
            else:
                self.won = True

    def draw(self, surf, paused, highscore):
        surf.fill(BG)
        draw_grid(surf, self.cols, self.rows)
        draw_walls(surf, self.walls)
        draw_food(surf, self.food, gold=False)
        if self.gold:
            draw_food(surf, self.gold, gold=True)
        draw_snake(surf, self.snake)
        if self.flash > 0:
            flash_screen(surf, self.cols, self.rows,
                         FLASH_COL if self.flash <= 4 else GOLD_COL,
                         self.flash)
            self.flash -= 1
        draw_hud(surf, self.score, highscore,
                 self.lv["name"], self.cols, self.lv["fps"], paused)


# ── Main loop ─────────────────────────────────────────────────────────────────
def main():
    pygame.init()
    pygame.display.set_caption("🐍  Nokia Snake – Enhanced")

    highscore  = load_highscore()
    level_idx  = 0
    game       = Game(level_idx)
    paused     = False
    state      = "PLAYING"   # PLAYING | DEAD | WON | LEVELUP

    # size window to current level
    def resize(g):
        w = g.cols * CELL
        h = g.rows * CELL + HUD_H
        return pygame.display.set_mode((w, h))

    screen = resize(game)
    clock  = pygame.time.Clock()

    levelup_timer = 0

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                if game.score > highscore:
                    save_highscore(game.score)
                pygame.quit()
                sys.exit()

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit()
                    sys.exit()

                if event.key == pygame.K_p and state == "PLAYING":
                    paused = not paused

                if state in ("DEAD", "WON"):
                    if event.key == pygame.K_r:
                        level_idx = 0
                        game      = Game(0)
                        screen    = resize(game)
                        state     = "PLAYING"
                        paused    = False
                    elif event.key == pygame.K_q:
                        if game.score > highscore:
                            save_highscore(game.score)
                        pygame.quit()
                        sys.exit()

                elif state == "LEVELUP":
                    pass  # handled by timer

                elif state == "PLAYING" and not paused:
                    game.handle_key(event.key)

        # ── tick ──────────────────────────────────────────────────────────────
        if state == "PLAYING" and not paused:
            result = game.step()
            if result == "LEVELUP":
                state = "LEVELUP"
                levelup_timer = game.lv["fps"] * 2   # show for ~2 s
            elif not game.alive:
                state = "DEAD"
                if game.score > highscore:
                    highscore = game.score
                    save_highscore(highscore)
            elif game.won:
                state = "WON"
                if game.score > highscore:
                    highscore = game.score
                    save_highscore(highscore)

        elif state == "LEVELUP":
            levelup_timer -= 1
            if levelup_timer <= 0:
                level_idx += 1
                new_score   = game.score
                game        = Game(level_idx)
                game.score  = new_score
                screen      = resize(game)
                state       = "PLAYING"

        # ── draw ──────────────────────────────────────────────────────────────
        game.draw(screen, paused, highscore)

        if state == "DEAD":
            draw_overlay(screen, [
                ("GAME OVER",       0, FOOD_COL),
                (f"Score: {game.score}",  1, TEXT_COL),
                (f"Best:  {highscore}",   1, GOLD_COL),
                ("[R] Restart   [Q] Quit", 2, GRID_LINE),
            ], game.cols, game.rows)

        elif state == "WON":
            draw_overlay(screen, [
                ("YOU ARE A LEGEND!", 0, GOLD_COL),
                (f"Score: {game.score}", 1, SNAKE_HEAD),
                (f"Best:  {highscore}",  1, GOLD_COL),
                ("[R] Restart   [Q] Quit", 2, GRID_LINE),
            ], game.cols, game.rows)

        elif state == "LEVELUP":
            next_lv = LEVELS[min(game.level_idx + 1, len(LEVELS) - 1)]
            draw_overlay(screen, [
                ("LEVEL UP!",               0, GOLD_COL),
                (next_lv["name"],           1, SNAKE_HEAD),
                ("Map grows • Speed ↑",     2, TEXT_COL),
            ], game.cols, game.rows)

        pygame.display.flip()
        clock.tick(game.lv["fps"])


if __name__ == "__main__":
    main()
