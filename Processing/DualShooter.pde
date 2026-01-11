// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                                                                              ║
// ║   DUAL SHOOTER PRO - Versión Mejorada                                       ║
// ║   Proyecto: FPGA Game Controller                                            ║
// ║   Versión: 3.0 - Full Screen + Better Collision                             ║
// ║                                                                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
//
// CONTROLES:
//   - FPGA Acelerómetro: Mover nave ARRIBA/ABAJO
//   - FPGA SW[0]: Disparar cañón izquierdo
//   - FPGA SW[1]: Disparar cañón derecho
//   - Teclado W/S o Flechas: Mover
//   - Teclado A/D: Disparar
//   - P = Pausar / R = Reiniciar
//
// ════════════════════════════════════════════════════════════════════════════════

import processing.serial.*;

// ══════════════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN FPGA
// ══════════════════════════════════════════════════════════════════════════════
Serial fpgaSerial;
boolean useFPGA = true;
String SERIAL_PORT = "COM3";
int SERIAL_BAUD = 115200;

// ══════════════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN DE PANTALLA (se calcula en setup para fullScreen)
// ══════════════════════════════════════════════════════════════════════════════
int SCREEN_W;
int SCREEN_H;
final int FPS = 60;

// ══════════════════════════════════════════════════════════════════════════════
// COLORES - Paleta cyberpunk/neon
// ══════════════════════════════════════════════════════════════════════════════
color BG_COLOR = color(10, 10, 20);
color PLAYER_COLOR = color(0, 255, 220);
color PLAYER_GLOW = color(0, 150, 180);
color CANNON_LEFT_COLOR = color(255, 80, 120);
color CANNON_RIGHT_COLOR = color(80, 180, 255);
color BULLET_LEFT_COLOR = color(255, 50, 80);
color BULLET_RIGHT_COLOR = color(50, 150, 255);
color ENEMY_LEFT_COLOR = color(255, 150, 50);
color ENEMY_RIGHT_COLOR = color(200, 50, 255);
color EXPLOSION_COLOR = color(255, 200, 50);
color TEXT_COLOR = color(255, 255, 255);
color ACCENT_COLOR = color(255, 220, 0);
color SHIELD_COLOR = color(100, 200, 255, 100);

// ══════════════════════════════════════════════════════════════════════════════
// JUGADOR Y CAÑONES
// ══════════════════════════════════════════════════════════════════════════════
float playerX, playerY;
float playerSize = 60;
float cannonOffset = 100;
float playerSpeed = 14;    // ULTRA RÁPIDO
float playerMinY = 120;
float playerMaxY;
float playerTargetY;  // Para movimiento suave

// ══════════════════════════════════════════════════════════════════════════════
// BALAS
// ══════════════════════════════════════════════════════════════════════════════
ArrayList<Bullet> bullets;
float bulletSpeed = 20;
int shootCooldown = 60;   // MÁS RÁPIDO
int lastShootLeft = 0;
int lastShootRight = 0;

// ══════════════════════════════════════════════════════════════════════════════
// ENEMIGOS
// ══════════════════════════════════════════════════════════════════════════════
ArrayList<Enemy> enemies;
float enemySpeed = 4;
int spawnInterval = 1200;
int lastSpawn = 0;

// ══════════════════════════════════════════════════════════════════════════════
// ESTRELLAS DE FONDO
// ══════════════════════════════════════════════════════════════════════════════
ArrayList<Star> stars;
int numStars = 150;

// ══════════════════════════════════════════════════════════════════════════════
// EXPLOSIONES Y PARTÍCULAS
// ══════════════════════════════════════════════════════════════════════════════
ArrayList<Explosion> explosions;
ArrayList<Particle> particles;

// ══════════════════════════════════════════════════════════════════════════════
// ESTADO DEL JUEGO
// ══════════════════════════════════════════════════════════════════════════════
enum GameState { MENU, RUNNING, PAUSED, GAME_OVER }
GameState state = GameState.MENU;
int score = 0;
int highScore = 0;
int lives = 5;
int level = 1;
int enemiesKilled = 0;
int combo = 0;
int lastKillTime = 0;

// ══════════════════════════════════════════════════════════════════════════════
// INPUT
// ══════════════════════════════════════════════════════════════════════════════
boolean keyUpPressed = false;
boolean keyDownPressed = false;
boolean keyLeftPressed = false;
boolean keyRightPressed = false;

// FPGA input
boolean fpgaUp = false;
boolean fpgaDown = false;
String lastFpgaCmd = "";
int fpgaLastCmdTime = 0;

// ══════════════════════════════════════════════════════════════════════════════
// EFECTOS VISUALES
// ══════════════════════════════════════════════════════════════════════════════
float screenShake = 0;
float pulseEffect = 0;

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              CLASE STAR (FONDO)                              ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
class Star {
  float x, y;
  float speed;
  float size;
  float brightness;
  
  Star() {
    reset();
    x = random(SCREEN_W);
  }
  
  void reset() {
    x = SCREEN_W + 10;
    y = random(SCREEN_H);
    speed = random(1, 4);
    size = random(1, 3);
    brightness = random(100, 255);
  }
  
  void update() {
    x -= speed;
    if (x < -10) reset();
  }
  
  void display() {
    noStroke();
    fill(brightness, brightness, brightness, brightness * 0.8);
    ellipse(x, y, size, size);
    // Trail
    fill(brightness, brightness, brightness, brightness * 0.3);
    ellipse(x + speed * 2, y, size * 0.5, size * 0.5);
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              CLASE BULLET                                    ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
class Bullet {
  float x, y;
  float speedX;
  boolean isLeft;
  float size = 14;
  
  Bullet(float x, float y, boolean left) {
    this.x = x;
    this.y = y;
    this.isLeft = left;
    this.speedX = left ? -bulletSpeed : bulletSpeed;
  }
  
  void update() {
    x += speedX;
  }
  
  void display() {
    noStroke();
    color col = isLeft ? BULLET_LEFT_COLOR : BULLET_RIGHT_COLOR;
    
    // Outer glow
    fill(col, 40);
    ellipse(x, y, size * 3, size * 2);
    
    // Core glow
    fill(col, 100);
    ellipse(x, y, size * 1.5, size * 1.2);
    
    // Main bullet
    fill(col);
    ellipse(x, y, size, size * 0.8);
    
    // Bright center
    fill(255, 255, 255, 220);
    ellipse(x, y, size * 0.4, size * 0.3);
    
    // Motion trail
    for (int i = 1; i <= 6; i++) {
      float trailX = x - speedX * i * 0.25;
      float alpha = 80 - i * 12;
      fill(col, alpha);
      float trailSize = size * (1 - i * 0.12);
      ellipse(trailX, y, trailSize, trailSize * 0.6);
    }
  }
  
  boolean isOffScreen() {
    return x < -50 || x > SCREEN_W + 50;
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              CLASE ENEMY                                     ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
class Enemy {
  float x, y;
  float speedX;
  boolean fromLeft;
  float size = 45;
  float wobble = 0;
  float rotation = 0;
  
  Enemy(boolean left) {
    this.fromLeft = left;
    this.x = left ? -size : SCREEN_W + size;
    this.y = random(playerMinY, playerMaxY);
    this.speedX = left ? enemySpeed : -enemySpeed;
    this.rotation = random(TWO_PI);
  }
  
  void update() {
    x += speedX;
    wobble += 0.08;
    rotation += 0.03;
    y += sin(wobble) * 0.8;  // Movimiento ondulado sutil
  }
  
  void display() {
    pushMatrix();
    translate(x, y);
    rotate(fromLeft ? 0 : PI);
    
    color col = fromLeft ? ENEMY_LEFT_COLOR : ENEMY_RIGHT_COLOR;
    
    // Pulsating glow
    float glowSize = size * 1.8 + sin(wobble * 2) * 5;
    noStroke();
    fill(col, 30);
    ellipse(0, 0, glowSize, glowSize);
    
    // Body hexagon-ish
    fill(col);
    beginShape();
    vertex(size * 0.5, 0);
    vertex(size * 0.2, -size * 0.35);
    vertex(-size * 0.3, -size * 0.3);
    vertex(-size * 0.4, 0);
    vertex(-size * 0.3, size * 0.3);
    vertex(size * 0.2, size * 0.35);
    endShape(CLOSE);
    
    // Inner details
    fill(red(col) * 0.6, green(col) * 0.6, blue(col) * 0.6);
    ellipse(-size * 0.1, 0, size * 0.4, size * 0.4);
    
    // Eye
    fill(255);
    ellipse(size * 0.1, 0, size * 0.25, size * 0.25);
    fill(0);
    float eyeX = (fromLeft ? 2 : -2);
    ellipse(size * 0.1 + eyeX, 0, size * 0.12, size * 0.12);
    
    // Thrusters
    float thrusterGlow = 150 + sin(wobble * 6) * 60;
    fill(255, 150, 50, thrusterGlow);
    ellipse(-size * 0.45, -size * 0.15, size * 0.3, size * 0.12);
    ellipse(-size * 0.45, size * 0.15, size * 0.3, size * 0.12);
    
    // Engine flame
    fill(255, 100, 0, thrusterGlow * 0.5);
    ellipse(-size * 0.55, 0, size * 0.2, size * 0.1);
    
    popMatrix();
  }
  
  // COLISIÓN MEJORADA: Ahora considera posición Y también
  boolean hitPlayer(float px, float py, float pSize) {
    float hitboxX = size * 0.5;  // Hitbox del jugador
    float hitboxY = size * 0.8;
    
    // El enemigo debe estar en el centro Y también estar cerca en Y de la nave
    float distX = abs(x - px);
    float distY = abs(y - py);
    
    return distX < hitboxX && distY < (pSize * 0.8);
  }
  
  boolean hitByBullet(Bullet b) {
    return dist(x, y, b.x, b.y) < (size * 0.5 + b.size * 0.5);
  }
  
  // Enemigo pasó sin ser destruido
  boolean escaped() {
    if (fromLeft) {
      return x > SCREEN_W + size;
    } else {
      return x < -size;
    }
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              CLASE PARTICLE                                  ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
class Particle {
  float x, y;
  float vx, vy;
  float size;
  float alpha;
  color col;
  
  Particle(float x, float y, color c) {
    this.x = x;
    this.y = y;
    this.col = c;
    this.vx = random(-5, 5);
    this.vy = random(-5, 5);
    this.size = random(3, 8);
    this.alpha = 255;
  }
  
  void update() {
    x += vx;
    y += vy;
    vx *= 0.95;
    vy *= 0.95;
    alpha -= 8;
    size *= 0.96;
  }
  
  void display() {
    noStroke();
    fill(col, alpha);
    ellipse(x, y, size, size);
  }
  
  boolean isDone() {
    return alpha <= 0 || size < 1;
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              CLASE EXPLOSION                                 ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
class Explosion {
  float x, y;
  float size = 15;
  float maxSize = 100;
  float alpha = 255;
  color col;
  
  Explosion(float x, float y, color c) {
    this.x = x;
    this.y = y;
    this.col = c;
  }
  
  void update() {
    size += 6;
    alpha -= 12;
  }
  
  void display() {
    noStroke();
    
    // Outer ring
    fill(col, alpha * 0.2);
    ellipse(x, y, size * 1.8, size * 1.8);
    
    // Main explosion
    fill(col, alpha * 0.6);
    ellipse(x, y, size, size);
    
    // Core
    fill(255, 255, 200, alpha);
    ellipse(x, y, size * 0.35, size * 0.35);
    
    // Spark lines
    stroke(col, alpha * 0.7);
    strokeWeight(2);
    for (int i = 0; i < 8; i++) {
      float angle = TWO_PI / 8 * i + size * 0.02;
      float innerR = size * 0.4;
      float outerR = size * 0.8;
      float x1 = x + cos(angle) * innerR;
      float y1 = y + sin(angle) * innerR;
      float x2 = x + cos(angle) * outerR;
      float y2 = y + sin(angle) * outerR;
      line(x1, y1, x2, y2);
    }
    noStroke();
  }
  
  boolean isDone() {
    return alpha <= 0;
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                                 SETUP                                        ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
void setup() {
  fullScreen();  // PANTALLA COMPLETA
  SCREEN_W = width;
  SCREEN_H = height;
  frameRate(FPS);
  smooth(4);
  
  // Inicializar estrellas
  stars = new ArrayList<Star>();
  for (int i = 0; i < numStars; i++) {
    stars.add(new Star());
  }
  
  // Intentar conectar FPGA
  if (useFPGA) {
    try {
      println("Puertos disponibles:");
      printArray(Serial.list());
      fpgaSerial = new Serial(this, SERIAL_PORT, SERIAL_BAUD);
      println("✅ FPGA conectada en " + SERIAL_PORT);
    } catch (Exception e) {
      println("⚠️ FPGA no disponible, usando teclado");
      useFPGA = false;
    }
  }
  
  initGame();
}

void initGame() {
  playerX = SCREEN_W / 2;
  playerY = SCREEN_H / 2;
  playerTargetY = playerY;
  playerMaxY = SCREEN_H - 100;
  
  bullets = new ArrayList<Bullet>();
  enemies = new ArrayList<Enemy>();
  explosions = new ArrayList<Explosion>();
  particles = new ArrayList<Particle>();
  
  score = 0;
  lives = 5;
  level = 1;
  enemiesKilled = 0;
  combo = 0;
  enemySpeed = 4;
  spawnInterval = 1200;
  
  state = GameState.RUNNING;
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                                 DRAW                                         ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
void draw() {
  // Efectos de pantalla
  pulseEffect += 0.05;
  if (screenShake > 0) screenShake *= 0.9;
  
  pushMatrix();
  if (screenShake > 0.5) {
    translate(random(-screenShake, screenShake), random(-screenShake, screenShake));
  }
  
  // Fondo
  drawBackground();
  
  // Leer input FPGA
  readFPGAInput();
  
  // Lógica de input
  processInput();
  
  // Lógica del juego
  if (state == GameState.RUNNING) {
    updateGame();
  }
  
  // Dibujar
  drawGame();
  
  popMatrix();
  
  // HUD y Overlays (sin shake)
  drawHUD();
  drawOverlay();
}

void readFPGAInput() {
  // Leer TODOS los bytes disponibles (no solo uno)
  // Esto evita el retraso acumulado en el buffer serial
  char lastCmd = 0;
  boolean gotMovement = false;
  
  while (useFPGA && fpgaSerial != null && fpgaSerial.available() > 0) {
    char cmd = char(fpgaSerial.read());
    lastFpgaCmd = str(cmd);
    fpgaLastCmdTime = millis();
    
    // Acumular el último comando de movimiento
    if (cmd == 'U' || cmd == 'D') {
      lastCmd = cmd;
      gotMovement = true;
    }
    
    // Disparos inmediatos
    if (cmd == 'L' && state == GameState.RUNNING) {
      shootLeft();
    }
    if (cmd == 'R' && state == GameState.RUNNING) {
      shootRight();
    }
  }
  
  // Aplicar el último comando de movimiento recibido
  if (gotMovement) {
    if (lastCmd == 'U') {
      fpgaUp = true;
      fpgaDown = false;
    } else if (lastCmd == 'D') {
      fpgaUp = false;
      fpgaDown = true;
    }
  }
  
  // Timeout para resetear flags FPGA si no hay datos recientes
  if (millis() - fpgaLastCmdTime > 40) {  // Timeout aún más corto
    fpgaUp = false;
    fpgaDown = false;
  }
}

void processInput() {
  if (state == GameState.RUNNING) {
    // Disparar con teclado
    if (keyLeftPressed) shootLeft();
    if (keyRightPressed) shootRight();
    
    // Mover jugador (teclado o FPGA)
    if (keyUpPressed || fpgaUp) {
      playerTargetY -= playerSpeed;
    }
    if (keyDownPressed || fpgaDown) {
      playerTargetY += playerSpeed;
    }
    
    // Limitar posición
    playerTargetY = constrain(playerTargetY, playerMinY, playerMaxY);
    
    // Movimiento suave pero RÁPIDO
    playerY = lerp(playerY, playerTargetY, 0.6);  // Más directo
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              LÓGICA DEL JUEGO                                ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
void updateGame() {
  // Actualizar estrellas
  for (Star s : stars) {
    s.update();
  }
  
  // Actualizar balas
  for (int i = bullets.size() - 1; i >= 0; i--) {
    Bullet b = bullets.get(i);
    b.update();
    if (b.isOffScreen()) {
      bullets.remove(i);
    }
  }
  
  // Spawn enemigos
  if (millis() - lastSpawn > spawnInterval) {
    boolean fromLeft = random(1) > 0.5;
    enemies.add(new Enemy(fromLeft));
    lastSpawn = millis();
  }
  
  // Actualizar enemigos
  for (int i = enemies.size() - 1; i >= 0; i--) {
    Enemy e = enemies.get(i);
    e.update();
    
    // Colisión con balas
    for (int j = bullets.size() - 1; j >= 0; j--) {
      Bullet b = bullets.get(j);
      // Solo balas del lado correcto pueden destruir al enemigo
      if ((e.fromLeft && b.isLeft) || (!e.fromLeft && !b.isLeft)) {
        if (e.hitByBullet(b)) {
          // Explosión!
          explosions.add(new Explosion(e.x, e.y, e.fromLeft ? ENEMY_LEFT_COLOR : ENEMY_RIGHT_COLOR));
          
          // Partículas
          for (int p = 0; p < 12; p++) {
            particles.add(new Particle(e.x, e.y, e.fromLeft ? ENEMY_LEFT_COLOR : ENEMY_RIGHT_COLOR));
          }
          
          enemies.remove(i);
          bullets.remove(j);
          
          // Combo system
          if (millis() - lastKillTime < 1000) {
            combo++;
          } else {
            combo = 1;
          }
          lastKillTime = millis();
          
          // Score con multiplicador de combo
          score += 100 * combo;
          enemiesKilled++;
          checkLevelUp();
          break;
        }
      }
    }
  }
  
  // COLISIÓN CON JUGADOR - MEJORADA
  for (int i = enemies.size() - 1; i >= 0; i--) {
    Enemy e = enemies.get(i);
    // Usar colisión mejorada que considera posición Y
    if (e.hitPlayer(playerX, playerY, playerSize)) {
      explosions.add(new Explosion(playerX, playerY, color(255, 50, 50)));
      screenShake = 15;
      enemies.remove(i);
      lives--;
      combo = 0;
      
      // Partículas de daño
      for (int p = 0; p < 20; p++) {
        particles.add(new Particle(playerX, playerY, color(255, 100, 100)));
      }
      
      if (lives <= 0) {
        state = GameState.GAME_OVER;
        if (score > highScore) highScore = score;
      }
    }
    
    // Enemigo escapó (no pierde vida, solo reinicia combo)
    if (e.escaped()) {
      enemies.remove(i);
      combo = 0;  // Perder combo por dejar escapar
    }
  }
  
  // Actualizar explosiones
  for (int i = explosions.size() - 1; i >= 0; i--) {
    Explosion ex = explosions.get(i);
    ex.update();
    if (ex.isDone()) {
      explosions.remove(i);
    }
  }
  
  // Actualizar partículas
  for (int i = particles.size() - 1; i >= 0; i--) {
    Particle p = particles.get(i);
    p.update();
    if (p.isDone()) {
      particles.remove(i);
    }
  }
}

void checkLevelUp() {
  if (enemiesKilled >= level * 12) {
    level++;
    enemySpeed += 0.4;
    spawnInterval = max(400, spawnInterval - 80);
    
    // Efecto de nivel
    for (int i = 0; i < 30; i++) {
      particles.add(new Particle(SCREEN_W/2, SCREEN_H/2, ACCENT_COLOR));
    }
    explosions.add(new Explosion(SCREEN_W/2, SCREEN_H/2, ACCENT_COLOR));
  }
}

void shootLeft() {
  if (millis() - lastShootLeft > shootCooldown) {
    float cannonX = playerX - cannonOffset;
    bullets.add(new Bullet(cannonX, playerY, true));
    lastShootLeft = millis();
    
    // Pequeño retroceso visual
    for (int i = 0; i < 4; i++) {
      particles.add(new Particle(cannonX, playerY, CANNON_LEFT_COLOR));
    }
  }
}

void shootRight() {
  if (millis() - lastShootRight > shootCooldown) {
    float cannonX = playerX + cannonOffset;
    bullets.add(new Bullet(cannonX, playerY, false));
    lastShootRight = millis();
    
    for (int i = 0; i < 4; i++) {
      particles.add(new Particle(cannonX, playerY, CANNON_RIGHT_COLOR));
    }
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                              RENDERIZADO                                     ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
void drawBackground() {
  // Gradiente de fondo
  noStroke();
  for (int y = 0; y < SCREEN_H; y++) {
    float inter = map(y, 0, SCREEN_H, 0, 1);
    color c = lerpColor(color(15, 15, 35), color(5, 5, 15), inter);
    stroke(c);
    line(0, y, SCREEN_W, y);
  }
  
  // Estrellas
  for (Star s : stars) {
    s.display();
  }
  
  // Grid sutil
  stroke(40, 40, 70, 25);
  strokeWeight(1);
  for (int x = 0; x < SCREEN_W; x += 80) {
    line(x, 0, x, SCREEN_H);
  }
  for (int y = 0; y < SCREEN_H; y += 80) {
    line(0, y, SCREEN_W, y);
  }
  
  // Línea central con gradiente
  for (int y = 0; y < SCREEN_H; y++) {
    float alpha = 15 + sin(y * 0.02 + pulseEffect) * 10;
    stroke(PLAYER_COLOR, alpha);
    strokeWeight(2);
    point(SCREEN_W/2, y);
  }
  
  noStroke();
}

void drawGame() {
  // Partículas (fondo)
  for (Particle p : particles) {
    p.display();
  }
  
  // Explosiones
  for (Explosion ex : explosions) {
    ex.display();
  }
  
  // Balas
  for (Bullet b : bullets) {
    b.display();
  }
  
  // Enemigos
  for (Enemy e : enemies) {
    e.display();
  }
  
  // Jugador
  drawPlayer();
}

void drawPlayer() {
  float px = playerX;
  float py = playerY;
  
  // Glow exterior grande
  noStroke();
  float glowPulse = 1 + sin(pulseEffect * 2) * 0.1;
  fill(PLAYER_GLOW, 20);
  ellipse(px, py, playerSize * 4 * glowPulse, playerSize * 4 * glowPulse);
  
  // Glow medio
  fill(PLAYER_COLOR, 40);
  ellipse(px, py, playerSize * 2.5, playerSize * 2.5);
  
  // Cuerpo principal
  fill(PLAYER_COLOR);
  ellipse(px, py, playerSize, playerSize);
  
  // Anillo interior
  stroke(255, 255, 255, 100);
  strokeWeight(2);
  noFill();
  ellipse(px, py, playerSize * 0.7, playerSize * 0.7);
  noStroke();
  
  // Centro brillante
  fill(255, 255, 255, 200);
  ellipse(px, py, playerSize * 0.35, playerSize * 0.35);
  
  // Core
  fill(PLAYER_COLOR);
  ellipse(px, py, playerSize * 0.15, playerSize * 0.15);
  
  // Cañones
  float cannonLeftX = px - cannonOffset;
  float cannonRightX = px + cannonOffset;
  
  drawCannon(cannonLeftX, py, true);
  drawCannon(cannonRightX, py, false);
  
  // Conexiones con glow
  stroke(PLAYER_COLOR, 60);
  strokeWeight(8);
  line(px - playerSize/2, py, cannonLeftX + 25, py);
  line(px + playerSize/2, py, cannonRightX - 25, py);
  
  stroke(PLAYER_COLOR, 150);
  strokeWeight(3);
  line(px - playerSize/2, py, cannonLeftX + 25, py);
  line(px + playerSize/2, py, cannonRightX - 25, py);
  
  noStroke();
}

void drawCannon(float x, float y, boolean isLeft) {
  pushMatrix();
  translate(x, y);
  
  color cannonColor = isLeft ? CANNON_LEFT_COLOR : CANNON_RIGHT_COLOR;
  boolean active = isLeft ? (keyLeftPressed || fpgaUp) : (keyRightPressed || fpgaDown);
  
  // Glow
  fill(cannonColor, 40);
  ellipse(0, 0, 70, 70);
  
  // Base
  fill(cannonColor);
  ellipse(0, 0, 50, 50);
  
  // Barrel
  rectMode(CENTER);
  fill(cannonColor);
  if (isLeft) {
    rect(-25, 0, 40, 18, 5);
    fill(red(cannonColor)*0.7, green(cannonColor)*0.7, blue(cannonColor)*0.7);
    rect(-30, 0, 20, 10, 3);
  } else {
    rect(25, 0, 40, 18, 5);
    fill(red(cannonColor)*0.7, green(cannonColor)*0.7, blue(cannonColor)*0.7);
    rect(30, 0, 20, 10, 3);
  }
  rectMode(CORNER);
  
  // Inner circle (activation indicator)
  if (active || (millis() - (isLeft ? lastShootLeft : lastShootRight) < 100)) {
    fill(255, 255, 255, 220);
  } else {
    fill(30, 30, 50);
  }
  ellipse(0, 0, 22, 22);
  
  popMatrix();
}

void drawHUD() {
  // Panel superior con gradiente
  noStroke();
  for (int y = 0; y < 70; y++) {
    float alpha = map(y, 0, 70, 200, 0);
    fill(0, 0, 0, alpha);
    rect(0, y, SCREEN_W, 1);
  }
  
  float hudY = 35;
  
  // Score
  textAlign(LEFT, CENTER);
  fill(TEXT_COLOR, 180);
  textSize(16);
  text("SCORE", 30, hudY - 12);
  fill(ACCENT_COLOR);
  textSize(32);
  text(nfc(score), 30, hudY + 12);
  
  // Combo
  if (combo > 1) {
    fill(255, 150, 50);
    textSize(18);
    text("x" + combo, 160, hudY);
  }
  
  // High Score
  textAlign(LEFT, CENTER);
  fill(TEXT_COLOR, 120);
  textSize(14);
  text("HIGH: " + nfc(highScore), 30, hudY + 40);
  
  // Nivel
  fill(TEXT_COLOR, 180);
  textSize(16);
  text("LEVEL", 250, hudY - 12);
  fill(PLAYER_COLOR);
  textSize(32);
  text(level, 250, hudY + 12);
  
  // Vidas
  fill(TEXT_COLOR, 180);
  textSize(16);
  text("LIVES", 380, hudY - 12);
  for (int i = 0; i < lives; i++) {
    fill(255, 80, 100);
    ellipse(385 + i * 28, hudY + 12, 20, 20);
    fill(255, 200, 200);
    ellipse(385 + i * 28, hudY + 12, 10, 10);
  }
  
  // Status FPGA
  textAlign(RIGHT, CENTER);
  fill(useFPGA ? color(50, 255, 150) : color(150));
  textSize(14);
  text(useFPGA ? "FPGA CONNECTED" : "KEYBOARD MODE", SCREEN_W - 30, hudY);
  
  if (useFPGA && lastFpgaCmd.length() > 0) {
    fill(ACCENT_COLOR, 180);
    textSize(12);
    text("CMD: " + lastFpgaCmd, SCREEN_W - 30, hudY + 20);
  }
  
  // Indicadores de movimiento
  float indicatorX = SCREEN_W - 60;
  float indicatorY = SCREEN_H / 2;
  
  fill(keyUpPressed || fpgaUp ? PLAYER_COLOR : color(60));
  textSize(24);
  textAlign(CENTER, CENTER);
  text("▲", indicatorX, indicatorY - 35);
  
  fill(keyDownPressed || fpgaDown ? PLAYER_COLOR : color(60));
  text("▼", indicatorX, indicatorY + 35);
  
  fill(100);
  textSize(11);
  text(useFPGA ? "TILT" : "W/S", indicatorX, indicatorY);
  
  // Instrucciones (abajo)
  textAlign(CENTER, BOTTOM);
  fill(80);
  textSize(12);
  String instructions = useFPGA ? 
    "TILT = Move | SW[0] = Left | SW[1] = Right | P = Pause" :
    "W/S = Move | A = Left | D = Right | P = Pause";
  text(instructions, SCREEN_W/2, SCREEN_H - 15);
}

void drawOverlay() {
  if (state == GameState.PAUSED) {
    // Dim background
    fill(0, 0, 0, 180);
    rect(0, 0, SCREEN_W, SCREEN_H);
    
    // Panel
    fill(30, 30, 60, 240);
    rectMode(CENTER);
    rect(SCREEN_W/2, SCREEN_H/2, 450, 200, 20);
    rectMode(CORNER);
    
    // Border glow
    stroke(PLAYER_COLOR, 100);
    strokeWeight(3);
    noFill();
    rectMode(CENTER);
    rect(SCREEN_W/2, SCREEN_H/2, 450, 200, 20);
    rectMode(CORNER);
    noStroke();
    
    textAlign(CENTER, CENTER);
    fill(PLAYER_COLOR);
    textSize(56);
    text("⏸ PAUSED", SCREEN_W/2, SCREEN_H/2 - 30);
    
    fill(TEXT_COLOR);
    textSize(20);
    text("Press 'P' to continue", SCREEN_W/2, SCREEN_H/2 + 40);
  }
  
  if (state == GameState.GAME_OVER) {
    // Red tint
    fill(80, 0, 0, 200);
    rect(0, 0, SCREEN_W, SCREEN_H);
    
    // Panel
    fill(40, 20, 30, 245);
    rectMode(CENTER);
    rect(SCREEN_W/2, SCREEN_H/2, 500, 300, 20);
    rectMode(CORNER);
    
    // Border
    stroke(255, 80, 80, 150);
    strokeWeight(4);
    noFill();
    rectMode(CENTER);
    rect(SCREEN_W/2, SCREEN_H/2, 500, 300, 20);
    rectMode(CORNER);
    noStroke();
    
    textAlign(CENTER, CENTER);
    
    // Title
    fill(255, 60, 80);
    textSize(64);
    text("GAME OVER", SCREEN_W/2, SCREEN_H/2 - 80);
    
    // Score
    fill(ACCENT_COLOR);
    textSize(36);
    text("Score: " + nfc(score), SCREEN_W/2, SCREEN_H/2 - 10);
    
    // Level
    fill(TEXT_COLOR);
    textSize(22);
    text("Level Reached: " + level, SCREEN_W/2, SCREEN_H/2 + 35);
    
    // High score
    if (score >= highScore && score > 0) {
      fill(255, 220, 50);
      textSize(20);
      text("★ NEW HIGH SCORE! ★", SCREEN_W/2, SCREEN_H/2 + 70);
    }
    
    // Restart
    fill(180);
    textSize(18);
    text("Press 'R' to restart", SCREEN_W/2, SCREEN_H/2 + 110);
  }
}

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║                                INPUT                                         ║
// ╚══════════════════════════════════════════════════════════════════════════════╝
void keyPressed() {
  if (key == 'w' || key == 'W' || keyCode == UP) {
    keyUpPressed = true;
  }
  if (key == 's' || key == 'S' || keyCode == DOWN) {
    keyDownPressed = true;
  }
  if (key == 'a' || key == 'A') {
    keyLeftPressed = true;
  }
  if (key == 'd' || key == 'D') {
    keyRightPressed = true;
  }
  
  // Pausa
  if (key == 'p' || key == 'P') {
    if (state == GameState.RUNNING) {
      state = GameState.PAUSED;
    } else if (state == GameState.PAUSED) {
      state = GameState.RUNNING;
    }
  }
  
  // Reiniciar
  if (key == 'r' || key == 'R') {
    if (state == GameState.GAME_OVER) {
      initGame();
    }
  }
  
  // Salir con ESC
  if (key == ESC) {
    key = 0;  // Cancelar salida por ESC
    if (state == GameState.RUNNING) {
      state = GameState.PAUSED;
    } else if (state == GameState.PAUSED) {
      exit();
    }
  }
}

void keyReleased() {
  if (key == 'w' || key == 'W' || keyCode == UP) {
    keyUpPressed = false;
  }
  if (key == 's' || key == 'S' || keyCode == DOWN) {
    keyDownPressed = false;
  }
  if (key == 'a' || key == 'A') {
    keyLeftPressed = false;
  }
  if (key == 'd' || key == 'D') {
    keyRightPressed = false;
  }
}
