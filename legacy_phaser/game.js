// =========================================================
// RH: Redhog — Phase 1 (เพิ่ม roundPixels: true เพื่อล็อกตำแหน่ง UI ไม่ให้ขยับ)
// =========================================================

const GAME_WIDTH = 480;
const GAME_HEIGHT = 270;
const PLAYER_SPEED = 90;

// ขนาดแผนที่โลกจริง (พิกเซล)
const MAP_WORLD_WIDTH = 40 * 32;   // 1280 px
const MAP_WORLD_HEIGHT = 25 * 32;  // 800 px

// -------------------------------------------------
// BootScene: สร้าง texture placeholder ทั้งหมดแบบ runtime
// -------------------------------------------------
class BootScene extends Phaser.Scene {
  constructor() { super('BootScene'); }

  create() {
    this.generatePlayerTextures();
    this.generateGroundTexture();
    this.generatePoringTexture();
    this.generateItemTextures();
    this.scene.start('WorldScene');
  }

  generatePlayerTextures() {
    const dirs = ['down', 'up', 'left', 'right'];
    dirs.forEach((dir) => {
      for (let frame = 0; frame < 2; frame++) {
        const key = `player_${dir}_${frame}`;
        const g = this.make.graphics({ x: 0, y: 0, add: false });
        const legOffset = frame === 0 ? -2 : 2;

        g.fillStyle(0x000000, 0.25);
        g.fillEllipse(8, 15, 10, 4);

        g.fillStyle(0x2b2b52, 1);
        g.fillRect(5 + legOffset * 0.2, 11, 3, 4);
        g.fillRect(8 - legOffset * 0.2, 11, 3, 4);

        g.fillStyle(0x8a5a34, 1);
        g.fillRect(4, 5, 9, 7);

        g.fillStyle(0xffdbac, 1);
        g.fillRect(4, 0, 9, 6);

        g.fillStyle(0xb33a2b, 1);
        g.fillRect(3, -1, 11, 3);

        g.fillStyle(0x1a1a1a, 1);
        if (dir === 'down') { g.fillRect(6, 3, 1, 1); g.fillRect(10, 3, 1, 1); }
        if (dir === 'left') { g.fillRect(4, 3, 1, 1); }
        if (dir === 'right') { g.fillRect(11, 3, 1, 1); }

        g.generateTexture(key, 17, 17);
        g.destroy();
      }
    });
  }

  generateGroundTexture() {
    const g = this.make.graphics({ x: 0, y: 0, add: false });
    g.fillStyle(0x4a7c3f, 1);
    g.fillRect(0, 0, 32, 32);
    g.fillStyle(0x548a47, 0.5);
    g.fillRect(0, 0, 16, 16);
    g.fillRect(16, 16, 16, 16);
    g.generateTexture('ground_tile', 32, 32);
    g.destroy();
  }

  generatePoringTexture() {
    const g = this.make.graphics({ x: 0, y: 0, add: false });
    g.fillStyle(0x000000, 0.2);
    g.fillEllipse(10, 17, 12, 4);
    g.fillStyle(0xc0392b, 1);
    g.fillEllipse(10, 10, 16, 14);
    g.fillStyle(0xffffff, 1);
    g.fillCircle(7, 8, 2);
    g.fillCircle(13, 8, 2);
    g.fillStyle(0x000000, 1);
    g.fillCircle(7, 8, 1);
    g.fillCircle(13, 8, 1);
    g.generateTexture('poring', 20, 20);
    g.destroy();
  }

  generateItemTextures() {
    const g1 = this.make.graphics({ x: 0, y: 0, add: false });
    g1.fillStyle(0xe74c3c, 1);
    g1.fillRect(3, 5, 10, 9);
    g1.fillStyle(0xecf0f1, 1);
    g1.fillRect(6, 2, 4, 3);
    g1.generateTexture('item_red_potion', 16, 16);
    g1.destroy();

    const g2 = this.make.graphics({ x: 0, y: 0, add: false });
    g2.fillStyle(0x27ae60, 1);
    g2.fillRect(7, 2, 2, 4);
    g2.fillStyle(0xd9534f, 1);
    g2.fillCircle(8, 10, 5);
    g2.generateTexture('item_apple', 16, 16);
    g2.destroy();

    const g3 = this.make.graphics({ x: 0, y: 0, add: false });
    g3.fillStyle(0x95a5a6, 1);
    g3.fillRect(7, 2, 2, 10);
    g3.fillStyle(0xd35400, 1);
    g3.fillRect(6, 12, 4, 3);
    g3.generateTexture('item_dagger', 16, 16);
    g3.destroy();
  }
}

// -------------------------------------------------
// WorldScene: แผนที่, ตัวละคร, มอนสเตอร์ และระบบควบคุม
// -------------------------------------------------
class WorldScene extends Phaser.Scene {
  constructor() { super('WorldScene'); }

  create() {
    this.isTouchDevice = this.sys.game.device.input.touch;

    this.buildMap();
    this.createPlayer();
    this.createAnimations();
    this.createMonsters();
    
    this.cameras.main.startFollow(this.player, true, 0.1, 0.1);
    this.cameras.main.setZoom(2);

    this.setupKeyboard();
    this.setupClickToMoveAndTargeting();

    if (this.isTouchDevice) {
      this.setupVirtualJoystick();
      this.setupTouchButtons();
    }

    this.scene.launch('UIScene', { player: this.player, monsters: this.monsters });
  }

  buildMap() {
    this.add.tileSprite(0, 0, MAP_WORLD_WIDTH, MAP_WORLD_HEIGHT, 'ground_tile').setOrigin(0, 0);
    this.physics.world.setBounds(0, 0, MAP_WORLD_WIDTH, MAP_WORLD_HEIGHT);
  }

  createPlayer() {
    this.player = this.physics.add.sprite(300, 300, 'player_down_0');
    this.player.setCollideWorldBounds(true);
    this.player.setSize(9, 6).setOffset(4, 10);
    this.player.direction = 'down';
    this.player.isMoving = false;
    this.player.isSitting = false;

    this.player.maxHp = 100;
    this.player.hp = 100;
    this.player.maxSp = 50;
    this.player.sp = 50;
    this.player.maxExp = 100;
    this.player.exp = 0;
    this.player.level = 1;
    this.player.statPoints = 0; 

    this.player.str = 1;
    this.player.agi = 1;
    this.player.vit = 1;
    this.player.int = 1;
    this.player.dex = 1;
    this.player.luk = 1;

    // ระบบช่องเก็บของ 6x6 (รวม 36 ช่อง)
    this.player.inventory = Array(36).fill(null);
    this.player.inventory[0] = { name: 'Red Potion', count: 15, icon: 'item_red_potion' };
    this.player.inventory[1] = { name: 'Apple', count: 5, icon: 'item_apple' };
    this.player.inventory[2] = { name: 'Novice Dagger', count: 1, icon: 'item_dagger' };

    this.player.lastAttackTime = 0;
  }

  createAnimations() {
    const dirs = ['down', 'up', 'left', 'right'];
    dirs.forEach((dir) => {
      this.anims.create({
        key: `walk_${dir}`,
        frames: [{ key: `player_${dir}_0` }, { key: `player_${dir}_1` }],
        frameRate: 6,
        repeat: -1,
      });
    });
  }

  createMonsters() {
    this.monsters = this.physics.add.group();
    for (let i = 0; i < 8; i++) {
      const x = Phaser.Math.Between(100, MAP_WORLD_WIDTH - 100);
      const y = Phaser.Math.Between(100, MAP_WORLD_HEIGHT - 100);
      const poring = this.monsters.create(x, y, 'poring');
      poring.setCollideWorldBounds(true);
      poring.maxHp = 6;
      poring.hp = 6;
      poring.wanderTimer = 0;
      poring.wanderDir = new Phaser.Math.Vector2(0, 0);
      poring.hpBarGfx = this.add.graphics();
      poring.setInteractive();
    }
  }

  setupKeyboard() {
    this.cursors = this.input.keyboard.createCursorKeys();
    this.keys = this.input.keyboard.addKeys('W,A,S,D,SPACE');
  }

  setupClickToMoveAndTargeting() {
    this.moveTarget = null;
    this.selectedTarget = null;
    this.targetRing = this.add.graphics();
    this.arrowGfx = this.add.graphics();

    this.input.on('pointerdown', (pointer) => {
      if (pointer.y < 70 && pointer.x < 150) return;
      if (pointer.y > GAME_HEIGHT - 35 && pointer.x < 100) return;
      if (pointer.y < 85 && pointer.x > GAME_WIDTH - 95) return;

      const uiScene = this.scene.get('UIScene');
      if (uiScene && (uiScene.isStatWindowOpen || uiScene.isInventoryWindowOpen)) {
        return;
      }

      const worldPoint = this.cameras.main.getWorldPoint(pointer.x, pointer.y);

      let clickedMonster = null;
      this.monsters.getChildren().forEach((m) => {
        if (!m.active) return;
        const dist = Phaser.Math.Distance.Between(worldPoint.x, worldPoint.y, m.x, m.y);
        if (dist < 16) {
          clickedMonster = m;
        }
      });

      if (clickedMonster) {
        this.selectedTarget = clickedMonster;
        this.moveTarget = null;
        this.arrowGfx.clear();
      } else {
        this.selectedTarget = null;
        this.moveTarget = { x: worldPoint.x, y: worldPoint.y };
      }
    });
  }

  setupVirtualJoystick() {
    const baseX = 70, baseY = GAME_HEIGHT - 70;
    this.joystick = {
      baseX, baseY,
      radius: 40,
      pointerId: null,
      vector: new Phaser.Math.Vector2(0, 0),
    };

    this.joyBase = this.add.circle(baseX, baseY, 40, 0xffffff, 0.15).setScrollFactor(0).setDepth(5000).setStrokeStyle(2, 0xffffff, 0.4);
    this.joyThumb = this.add.circle(baseX, baseY, 18, 0xffffff, 0.35).setScrollFactor(0).setDepth(5001);

    this.input.on('pointerdown', (pointer) => {
      const dist = Phaser.Math.Distance.Between(pointer.x, pointer.y, baseX, baseY);
      if (dist <= this.joystick.radius * 1.6 && this.joystick.pointerId === null) {
        this.joystick.pointerId = pointer.id;
      }
    });

    this.input.on('pointermove', (pointer) => {
      if (pointer.id !== this.joystick.pointerId) return;
      const dx = pointer.x - baseX;
      const dy = pointer.y - baseY;
      const dist = Math.min(Math.sqrt(dx * dx + dy * dy), this.joystick.radius);
      const angle = Math.atan2(dy, dx);
      this.joyThumb.setPosition(baseX + Math.cos(angle) * dist, baseY + Math.sin(angle) * dist);
      this.joystick.vector.set(dx, dy).normalize().scale(dist / this.joystick.radius);
    });

    this.input.on('pointerup', (pointer) => {
      if (pointer.id !== this.joystick.pointerId) return;
      this.joystick.pointerId = null;
      this.joystick.vector.set(0, 0);
      this.joyThumb.setPosition(baseX, baseY);
    });
  }

  setupTouchButtons() {
    const attackX = GAME_WIDTH - 45, attackY = GAME_HEIGHT - 45;
    const attackBtn = this.add.circle(attackX, attackY, 26, 0xb33a2b, 0.55).setScrollFactor(0).setDepth(5000).setInteractive();
    this.add.text(attackX, attackY, 'ATK', { fontSize: '10px', color: '#fff' }).setOrigin(0.5).setScrollFactor(0).setDepth(5001);
    attackBtn.on('pointerdown', () => this.doAttack());
  }

  doAttack() {
    if (this.player.isSitting) return;

    if (this.selectedTarget && this.selectedTarget.active) {
      const dist = Phaser.Math.Distance.Between(this.player.x, this.player.y, this.selectedTarget.x, this.selectedTarget.y);
      if (dist <= 40) {
        this.inflictDamageToMonster(this.selectedTarget);
      }
    } else {
      this.monsters.getChildren().forEach((m) => {
        if (!m.active) return;
        const dist = Phaser.Math.Distance.Between(this.player.x, this.player.y, m.x, m.y);
        if (dist <= 40) {
          this.inflictDamageToMonster(m);
        }
      });
    }
  }

  inflictDamageToMonster(monster) {
    this.cameras.main.flash(60, 255, 255, 255, false);
    
    const damage = 2 + Math.floor(this.player.str * 0.5);
    monster.hp -= damage;

    if (monster.hp <= 0) {
      if (monster.hpBarGfx) monster.hpBarGfx.clear();
      
      monster.setActive(false);
      monster.setVisible(false);
      monster.setVelocity(0, 0);

      if (this.selectedTarget === monster) this.selectedTarget = null;
      
      this.addExp(25);

      this.time.delayedCall(10000, () => {
        if (!monster.scene) return;
        const newX = Phaser.Math.Between(100, MAP_WORLD_WIDTH - 100);
        const newY = Phaser.Math.Between(100, MAP_WORLD_HEIGHT - 100);
        
        monster.setPosition(newX, newY);
        monster.hp = monster.maxHp;
        monster.setActive(true);
        monster.setVisible(true);
      });
    }
  }

  addExp(amount) {
    this.player.exp += amount;
    if (this.player.exp >= this.player.maxExp) {
      this.player.exp -= this.player.maxExp;
      this.player.level += 1;
      this.player.maxExp = Math.floor(this.player.maxExp * 1.4);
      this.player.statPoints += 1;
      
      this.player.hp = this.player.maxHp;
      this.player.sp = this.player.maxSp;

      this.cameras.main.flash(300, 255, 215, 0, false);
    }
  }

  update(time, delta) {
    this.handleMovement();
    this.updateMonsters(time, delta);
    this.updateTargetRing();
    this.drawOrbitingArrow();

    // Snap camera ไปที่ตำแหน่ง integer pixel เสมอ
    // ป้องกัน sub-pixel rendering ที่ทำให้เส้นขอบ UI เปลี่ยนขนาด
    const cam = this.cameras.main;
    cam.scrollX = Math.round(cam.scrollX);
    cam.scrollY = Math.round(cam.scrollY);
  }

  drawOrbitingArrow() {
    this.arrowGfx.clear();
    if (this.moveTarget) {
      const radius = 18;
      const angle = Phaser.Math.Angle.Between(this.player.x, this.player.y, this.moveTarget.x, this.moveTarget.y);
      
      const cx = this.player.x + Math.cos(angle) * radius;
      const cy = this.player.y + Math.sin(angle) * radius;

      const headSize = 5;
      const tipX = cx + Math.cos(angle) * headSize;
      const tipY = cy + Math.sin(angle) * headSize;
      const backX = cx - Math.cos(angle) * headSize;
      const backY = cy - Math.sin(angle) * headSize;

      const leftAngle = angle + Math.PI / 2;
      const rightAngle = angle - Math.PI / 2;
      const lX = backX + Math.cos(leftAngle) * headSize;
      const lY = backY + Math.sin(leftAngle) * headSize;
      const rX = backX + Math.cos(rightAngle) * headSize;
      const rY = backY + Math.sin(rightAngle) * headSize;

      this.arrowGfx.fillStyle(0x3498db, 0.95);
      this.arrowGfx.fillTriangle(tipX, tipY, lX, lY, rX, rY);
      this.arrowGfx.lineStyle(1, 0xffffff, 0.9);
      this.arrowGfx.strokeTriangle(tipX, tipY, lX, lY, rX, rY);
    }
  }

  updateTargetRing() {
    this.targetRing.clear();
    if (this.selectedTarget && this.selectedTarget.active) {
      this.targetRing.lineStyle(1, 0xe74c3c, 1);
      this.targetRing.strokeEllipse(this.selectedTarget.x, this.selectedTarget.y + 8, 20, 10);
    }
  }

  handleMovement() {
    if (this.player.isSitting) return;

    let vx = 0, vy = 0;

    if (this.cursors.left.isDown || this.keys.A.isDown || 
        this.cursors.right.isDown || this.keys.D.isDown || 
        this.cursors.up.isDown || this.keys.W.isDown || 
        this.cursors.down.isDown || this.keys.S.isDown ||
        (this.joystick && this.joystick.vector.length() > 0.15)) {
      
      if (this.cursors.left.isDown || this.keys.A.isDown) vx -= 1;
      if (this.cursors.right.isDown || this.keys.D.isDown) vx += 1;
      if (this.cursors.up.isDown || this.keys.W.isDown) vy -= 1;
      if (this.cursors.down.isDown || this.keys.S.isDown) vy += 1;

      if (this.joystick && this.joystick.vector.length() > 0.15) {
        vx += this.joystick.vector.x;
        vy += this.joystick.vector.y;
      }
      this.moveTarget = null;
      this.selectedTarget = null;
      this.arrowGfx.clear();
    } 
    else if (this.selectedTarget && this.selectedTarget.active) {
      const dist = Phaser.Math.Distance.Between(this.player.x, this.player.y, this.selectedTarget.x, this.selectedTarget.y);
      if (dist > 32) {
        const angle = Phaser.Math.Angle.Between(this.player.x, this.player.y, this.selectedTarget.x, this.selectedTarget.y);
        vx = Math.cos(angle);
        vy = Math.sin(angle);
      } else {
        vx = 0;
        vy = 0;
        const timeNow = this.time.now;
        if (!this.player.lastAutoAttack || timeNow - this.player.lastAutoAttack > 1000) {
          this.player.lastAutoAttack = timeNow;
          this.inflictDamageToMonster(this.selectedTarget);
        }
      }
    } 
    else if (this.moveTarget) {
      const dist = Phaser.Math.Distance.Between(this.player.x, this.player.y, this.moveTarget.x, this.moveTarget.y);
      if (dist > 4) {
        const angle = Phaser.Math.Angle.Between(this.player.x, this.player.y, this.moveTarget.x, this.moveTarget.y);
        vx = Math.cos(angle);
        vy = Math.sin(angle);
      } else {
        this.moveTarget = null;
        vx = 0;
        vy = 0;
        this.arrowGfx.clear();
      }
    }

    const moveVec = new Phaser.Math.Vector2(vx, vy);
    if (moveVec.length() > 0) {
      moveVec.normalize();
      this.player.setVelocity(moveVec.x * PLAYER_SPEED, moveVec.y * PLAYER_SPEED);
      this.player.isMoving = true;

      if (Math.abs(moveVec.x) > Math.abs(moveVec.y)) {
        this.player.direction = moveVec.x > 0 ? 'right' : 'left';
      } else {
        this.player.direction = moveVec.y > 0 ? 'down' : 'up';
      }
      this.player.anims.play(`walk_${this.player.direction}`, true);
    } else {
      this.player.setVelocity(0, 0);
      if (this.player.isMoving) {
        this.player.isMoving = false;
        this.player.anims.stop();
        this.player.setTexture(`player_${this.player.direction}_0`);
      }
    }
  }

  updateMonsters(time, delta) {
    this.monsters.getChildren().forEach((m) => {
      if (!m.active) return;

      const distToPlayer = Phaser.Math.Distance.Between(m.x, m.y, this.player.x, this.player.y);

      if (distToPlayer < 100) {
        const angle = Phaser.Math.Angle.Between(m.x, m.y, this.player.x, this.player.y);
        m.wanderDir.setToPolar(angle, 1);

        if (distToPlayer <= 20) {
          if (!m.lastHitTime || time - m.lastHitTime > 1500) {
            m.lastHitTime = time;
            const incomingDamage = Math.max(2, 5 - Math.floor(this.player.vit * 0.2));
            this.player.hp = Math.max(0, this.player.hp - incomingDamage);
            this.cameras.main.flash(75, 255, 0, 0, false);
          }
        }
      } else {
        m.wanderTimer -= delta;
        if (m.wanderTimer <= 0) {
          m.wanderTimer = Phaser.Math.Between(1500, 4000);
          const angle = Phaser.Math.FloatBetween(0, Math.PI * 2);
          m.wanderDir.setToPolar(angle, 1);
        }
      }

      m.setVelocity(m.wanderDir.x * 14, m.wanderDir.y * 14);

      m.x = Phaser.Math.Clamp(m.x, 20, MAP_WORLD_WIDTH - 20);
      m.y = Phaser.Math.Clamp(m.y, 20, MAP_WORLD_HEIGHT - 20);

      if (m.hpBarGfx && m.active) {
        m.hpBarGfx.clear();
        const barWidth = 16;
        const barHeight = 3;
        const bx = m.x - barWidth / 2;
        const by = m.y - 16;

        m.hpBarGfx.fillStyle(0x000000, 0.5);
        m.hpBarGfx.fillRect(bx, by, barWidth, barHeight);

        const hpPercent = Math.max(0, m.hp / m.maxHp);
        m.hpBarGfx.fillStyle(0xe74c3c, 1);
        m.hpBarGfx.fillRect(bx, by, barWidth * hpPercent, barHeight);
      }
    });
  }
}

// -------------------------------------------------
// UIScene: UI เลือด, Stat Window, Inventory Grid 6x6 และ Mini Map
// -------------------------------------------------
class UIScene extends Phaser.Scene {
  constructor() { super('UIScene'); }

  init(data) {
    this.player = data.player;
    this.monsters = data.monsters;
    this.isStatWindowOpen = false;
    this.isInventoryWindowOpen = false;
  }

  create() {
    // ล็อก camera ของ UIScene ไม่ให้ขยับเลย
    this.cameras.main.setScroll(0, 0);

    // --- UI เลือด มุมซ้ายบน ---
    const bg = this.add.rectangle(10, 10, 140, 52, 0x000000, 0.75).setOrigin(0, 0).setScrollFactor(0);
    bg.setStrokeStyle(1, 0x999999, 1);

    this.titleText = this.add.text(14, 13, 'RH: Novice (Lv. 1)', {
      fontSize: '8px', color: '#ffffff', fontStyle: 'bold'
    }).setScrollFactor(0);

    this.add.text(14, 23, 'HP', { fontSize: '7px', color: '#2ecc71', fontStyle: 'bold' }).setScrollFactor(0);
    this.playerHpBg = this.add.rectangle(30, 24, 65, 4, 0x444444).setOrigin(0, 0).setScrollFactor(0);
    this.playerHpBar = this.add.rectangle(30, 24, 65, 4, 0x2ecc71).setOrigin(0, 0).setScrollFactor(0);
    this.hpText = this.add.text(98, 22, '100/100', { fontSize: '6px', color: '#ffffff' }).setScrollFactor(0);

    this.add.text(14, 31, 'SP', { fontSize: '7px', color: '#3498db', fontStyle: 'bold' }).setScrollFactor(0);
    this.playerSpBg = this.add.rectangle(30, 32, 65, 4, 0x444444).setOrigin(0, 0).setScrollFactor(0);
    this.playerSpBar = this.add.rectangle(30, 32, 65, 4, 0x3498db).setOrigin(0, 0).setScrollFactor(0);
    this.spText = this.add.text(98, 30, '50/50', { fontSize: '6px', color: '#ffffff' }).setScrollFactor(0);

    this.add.text(14, 39, 'XP', { fontSize: '7px', color: '#f1c40f', fontStyle: 'bold' }).setScrollFactor(0);
    this.playerExpBg = this.add.rectangle(30, 40, 65, 4, 0x444444).setOrigin(0, 0).setScrollFactor(0);
    this.playerExpBar = this.add.rectangle(30, 40, 0, 4, 0xf1c40f).setOrigin(0, 0).setScrollFactor(0);
    this.expText = this.add.text(98, 38, '0/100', { fontSize: '6px', color: '#ffffff' }).setScrollFactor(0);

    // --- Mini Map มุมขวาบน ---
    this.minimapWidth = 80;
    this.minimapHeight = 50;
    this.minimapX = GAME_WIDTH - this.minimapWidth - 10;
    this.minimapY = 10;

    this.minimapBg = this.add.rectangle(this.minimapX, this.minimapY, this.minimapWidth, this.minimapHeight, 0x000000, 0.65).setOrigin(0, 0).setScrollFactor(0);
    this.minimapBg.setStrokeStyle(1, 0x999999, 1);
    this.minimapBg.setInteractive();

    this.minimapBg.on('pointerdown', (pointer) => {
      if (pointer.event) pointer.event.stopPropagation();
      const localXPos = pointer.x - this.minimapX;
      const localYPos = pointer.y - this.minimapY;

      const targetWorldX = (localXPos / this.minimapWidth) * MAP_WORLD_WIDTH;
      const targetWorldY = (localYPos / this.minimapHeight) * MAP_WORLD_HEIGHT;

      const worldScene = this.scene.get('WorldScene');
      if (worldScene) {
        worldScene.moveTarget = { x: targetWorldX, y: targetWorldY };
        worldScene.selectedTarget = null;
      }
    });

    this.minimapGfx = this.add.graphics().setScrollFactor(0);
    this.minimapPathGfx = this.add.graphics().setScrollFactor(0);

    // --- ปุ่ม STAT [C] (ซ้ายล่าง) ---
    const statBtnX = 26, statBtnY = GAME_HEIGHT - 18;
    const statBtnBg = this.add.rectangle(statBtnX, statBtnY, 40, 16, 0x2c3e50, 0.9).setOrigin(0.5, 0.5).setScrollFactor(0);
    statBtnBg.setStrokeStyle(1, 0xcccccc, 1);
    statBtnBg.setInteractive({ useHandCursor: true });

    this.add.text(statBtnX, statBtnY, 'STAT [C]', {
      fontSize: '6px', color: '#ffffff', fontStyle: 'bold'
    }).setOrigin(0.5, 0.5).setScrollFactor(0);

    statBtnBg.on('pointerdown', (pointer) => {
      if (pointer.event) pointer.event.stopPropagation();
      this.toggleStatWindow();
    });

    // --- ปุ่ม INV [B] (ซ้ายล่าง ต่อจากปุ่ม Stat) ---
    const invBtnX = 70, invBtnY = GAME_HEIGHT - 18;
    const invBtnBg = this.add.rectangle(invBtnX, invBtnY, 40, 16, 0x8e44ad, 0.9).setOrigin(0.5, 0.5).setScrollFactor(0);
    invBtnBg.setStrokeStyle(1, 0xcccccc, 1);
    invBtnBg.setInteractive({ useHandCursor: true });

    this.add.text(invBtnX, invBtnY, 'INV [B]', {
      fontSize: '6px', color: '#ffffff', fontStyle: 'bold'
    }).setOrigin(0.5, 0.5).setScrollFactor(0);

    invBtnBg.on('pointerdown', (pointer) => {
      if (pointer.event) pointer.event.stopPropagation();
      this.toggleInventoryWindow();
    });

    // --- สร้างหน้าต่าง Stat และ Inventory ---
    this.createStatWindow();
    this.createInventoryWindow();

    this.input.keyboard.on('keydown-C', () => {
      this.toggleStatWindow();
    });

    this.input.keyboard.on('keydown-B', () => {
      this.toggleInventoryWindow();
    });
  }

  createStatWindow() {
    const winWidth = 140;
    const winHeight = 150;
    const winX = Math.floor(GAME_WIDTH / 2 - winWidth / 2);
    const winY = Math.floor(GAME_HEIGHT / 2 - winHeight / 2);
    
    this.statElements = [];

    const winBg = this.add.rectangle(winX, winY, winWidth, winHeight, 0x1e1e2f, 0.95).setOrigin(0, 0);
    winBg.setStrokeStyle(2, 0x3498db, 1);
    winBg.setInteractive();
    winBg.on('pointerdown', (pointer) => { if (pointer.event) pointer.event.stopPropagation(); });

    const winTitle = this.add.text(winX + winWidth / 2, winY + 8, '- CHARACTER STATS -', {
      fontSize: '8px', color: '#f1c40f', fontStyle: 'bold'
    }).setOrigin(0.5, 0);

    const closeBtn = this.add.rectangle(winX + winWidth - 16, winY + 6, 12, 12, 0xe74c3c, 1).setOrigin(0, 0);
    const closeText = this.add.text(winX + winWidth - 10, winY + 12, 'X', { fontSize: '7px', color: '#ffffff', fontStyle: 'bold' }).setOrigin(0.5, 0.5);
    closeBtn.setInteractive();
    closeBtn.on('pointerdown', (pointer) => {
      if (pointer.event) pointer.event.stopPropagation();
      this.toggleStatWindow();
    });

    this.statHeaderInfo = this.add.text(winX + 12, winY + 22, '', { fontSize: '7px', color: '#ffffff', fontStyle: 'bold' });

    this.statTexts = {};
    this.plusButtons = [];

    const statsConfig = [
      { key: 'str', label: 'STR' },
      { key: 'agi', label: 'AGI' },
      { key: 'vit', label: 'VIT' },
      { key: 'int', label: 'INT' },
      { key: 'dex', label: 'DEX' },
      { key: 'luk', label: 'LUK' }
    ];

    let startY = winY + 38;
    statsConfig.forEach((s, index) => {
      const y = startY + (index * 15);
      const label = this.add.text(winX + 12, y, `${s.label} :`, { fontSize: '7px', color: '#ffffff', fontStyle: 'bold' });
      const val = this.add.text(winX + 55, y, '1', { fontSize: '7px', color: '#f1c40f', fontStyle: 'bold' });

      const plusBg = this.add.rectangle(winX + 115, y + 3, 16, 12, 0x27ae60, 1).setOrigin(0.5, 0.5);
      const plusTxt = this.add.text(winX + 115, y + 3, '+', { fontSize: '9px', color: '#ffffff', fontStyle: 'bold' }).setOrigin(0.5, 0.5);
      plusBg.setInteractive({ useHandCursor: true });

      plusBg.on('pointerdown', (pointer) => {
        if (pointer.event) pointer.event.stopPropagation();
        if (this.player && this.player.statPoints > 0) {
          this.player[s.key]++;
          this.player.statPoints--;
        }
      });

      this.statTexts[s.key] = val;
      this.plusButtons.push({ bg: plusBg, txt: plusTxt });

      this.statElements.push(label, val, plusBg, plusTxt);
    });

    this.statElements.push(winBg, winTitle, closeBtn, closeText, this.statHeaderInfo);
    this.statElements.forEach(el => { el.setVisible(false); el.setScrollFactor(0); });
  }

  createInventoryWindow() {
    const winWidth = 142;
    const winHeight = 150;
    const winX = Math.floor(GAME_WIDTH / 2 - winWidth / 2);
    const winY = Math.floor(GAME_HEIGHT / 2 - winHeight / 2);
    
    this.invElements = [];

    const winBg = this.add.rectangle(winX, winY, winWidth, winHeight, 0x1e1e2f, 0.95).setOrigin(0, 0);
    winBg.setStrokeStyle(2, 0x8e44ad, 1);
    winBg.setInteractive();
    winBg.on('pointerdown', (pointer) => { if (pointer.event) pointer.event.stopPropagation(); });

    const winTitle = this.add.text(winX + winWidth / 2, winY + 8, '- INVENTORY (6x6) -', {
      fontSize: '8px', color: '#f1c40f', fontStyle: 'bold'
    }).setOrigin(0.5, 0);

    const closeBtn = this.add.rectangle(winX + winWidth - 16, winY + 6, 12, 12, 0xe74c3c, 1).setOrigin(0, 0);
    const closeText = this.add.text(winX + winWidth - 10, winY + 12, 'X', { fontSize: '7px', color: '#ffffff', fontStyle: 'bold' }).setOrigin(0.5, 0.5);
    closeBtn.setInteractive();
    closeBtn.on('pointerdown', (pointer) => {
      if (pointer.event) pointer.event.stopPropagation();
      this.toggleInventoryWindow();
    });

    this.invElements.push(winBg, winTitle, closeBtn, closeText);

    // สร้างตารางช่องไอเท็ม 6x6 (36 ช่อง) จัดให้อยู่กึ่งกลางหน้าต่างพอดี
    this.invSlotItems = [];
    const slotSize = 16;
    const gap = 2;
    const gridTotalWidth = (6 * slotSize) + (5 * gap);
    const startX = Math.floor(winX + (winWidth - gridTotalWidth) / 2);
    const startY = winY + 28;

    for (let row = 0; row < 6; row++) {
      for (let col = 0; col < 6; col++) {
        const sx = startX + col * (slotSize + gap);
        const sy = startY + row * (slotSize + gap);

        const slotBg = this.add.rectangle(sx, sy, slotSize, slotSize, 0x2c2c3e).setOrigin(0, 0);
        slotBg.setStrokeStyle(1, 0x4a4a6a);

        const slotIcon = this.add.image(sx + 8, sy + 8, '').setVisible(false);
        const slotCount = this.add.text(sx + 14, sy + 14, '', { fontSize: '5px', color: '#ffffff' }).setOrigin(1, 1);

        this.invElements.push(slotBg, slotIcon, slotCount);
        this.invSlotItems.push({ icon: slotIcon, countText: slotCount });
      }
    }

    this.invElements.forEach(el => { el.setVisible(false); el.setScrollFactor(0); });
  }

  toggleStatWindow() {
    this.isStatWindowOpen = !this.isStatWindowOpen;
    this.statElements.forEach(el => el.setVisible(this.isStatWindowOpen));
    if (this.isStatWindowOpen) {
      this.isInventoryWindowOpen = false;
      this.invElements.forEach(el => el.setVisible(false));
    }
  }

  toggleInventoryWindow() {
    this.isInventoryWindowOpen = !this.isInventoryWindowOpen;
    this.invElements.forEach(el => el.setVisible(this.isInventoryWindowOpen));
    if (this.isInventoryWindowOpen) {
      this.isStatWindowOpen = false;
      this.statElements.forEach(el => el.setVisible(false));
    }
  }

  update() {
    if (!this.player) return;

    // บังคับล็อก camera ของ UIScene ไว้ที่ (0,0) ทุกเฟรม
    this.cameras.main.setScroll(0, 0);

    this.titleText.setText(`RH: Novice (Lv. ${this.player.level})`);

    const hpPercent = Math.max(0, this.player.hp / this.player.maxHp);
    this.playerHpBar.width = 65 * hpPercent;
    this.hpText.setText(`${Math.floor(this.player.hp)}/${this.player.maxHp}`);

    const spPercent = Math.max(0, this.player.sp / this.player.maxSp);
    this.playerSpBar.width = 65 * spPercent;
    this.spText.setText(`${Math.floor(this.player.sp)}/${this.player.maxSp}`);

    const expPercent = Math.max(0, this.player.exp / this.player.maxExp);
    this.playerExpBar.width = 65 * expPercent;
    this.expText.setText(`${this.player.exp}/${this.player.maxExp}`);

    if (this.isStatWindowOpen) {
      this.statHeaderInfo.setText(`Job: Novice  |  Points: ${this.player.statPoints}`);

      const keys = ['str', 'agi', 'vit', 'int', 'dex', 'luk'];
      keys.forEach((k) => {
        if (this.statTexts[k]) {
          this.statTexts[k].setText(`${this.player[k]}`);
        }
      });

      const hasPoints = this.player.statPoints > 0;
      this.plusButtons.forEach((btn) => {
        btn.bg.alpha = hasPoints ? 1.0 : 0.4;
        btn.txt.alpha = hasPoints ? 1.0 : 0.4;
      });
    }

    if (this.isInventoryWindowOpen) {
      for (let i = 0; i < 36; i++) {
        const item = this.player.inventory[i];
        const slot = this.invSlotItems[i];
        if (item) {
          slot.icon.setTexture(item.icon);
          slot.icon.setVisible(true);
          slot.countText.setText(item.count > 1 ? item.count : '');
        } else {
          slot.icon.setVisible(false);
          slot.countText.setText('');
        }
      }
    }

    // --- เรนเดอร์ Mini Map และเส้นประนำทาง ---
    this.minimapGfx.clear();
    this.minimapPathGfx.clear();

    const scaleX = this.minimapWidth / MAP_WORLD_WIDTH;
    const scaleY = this.minimapHeight / MAP_WORLD_HEIGHT;

    const worldScene = this.scene.get('WorldScene');

    if (worldScene && worldScene.moveTarget) {
      const startMiniX = this.minimapX + (this.player.x * scaleX);
      const startMiniY = this.minimapY + (this.player.y * scaleY);
      const endMiniX = this.minimapX + (worldScene.moveTarget.x * scaleX);
      const endMiniY = this.minimapY + (worldScene.moveTarget.y * scaleY);

      const dist = Phaser.Math.Distance.Between(startMiniX, startMiniY, endMiniX, endMiniY);
      const angle = Phaser.Math.Angle.Between(startMiniX, startMiniY, endMiniX, endMiniY);

      const stepLen = 4;
      const dashLen = 2;
      let curr = 0;

      this.minimapPathGfx.lineStyle(1, 0x3498db, 0.9);
      while (curr < dist) {
        const x1 = startMiniX + Math.cos(angle) * curr;
        const y1 = startMiniY + Math.sin(angle) * curr;
        const x2 = startMiniX + Math.cos(angle) * Math.min(curr + dashLen, dist);
        const y2 = startMiniY + Math.sin(angle) * Math.min(curr + dashLen, dist);

        this.minimapPathGfx.strokeLineShape(new Phaser.Geom.Line(x1, y1, x2, y2));
        curr += stepLen;
      }
    }

    if (this.monsters) {
      this.monsters.getChildren().forEach((m) => {
        if (m.active) {
          const mx = this.minimapX + (m.x * scaleX);
          const my = this.minimapY + (m.y * scaleY);
          this.minimapGfx.fillStyle(0xe74c3c, 1);
          this.minimapGfx.fillPoint(mx, my, 2);
        }
      });
    }

    const px = this.minimapX + (this.player.x * scaleX);
    const py = this.minimapY + (this.player.y * scaleY);
    this.minimapGfx.fillStyle(0x2ecc71, 1);
    this.minimapGfx.fillPoint(px, py, 3);
  }
}

// -------------------------------------------------
// Game Config
// -------------------------------------------------
const config = {
  type: Phaser.AUTO,
  parent: 'game-container',
  width: GAME_WIDTH,
  height: GAME_HEIGHT,
  pixelArt: true,
  roundPixels: true, // ล็อคพิกเซลไม่ให้เกิดอาการสั่นหรือขยับ
  backgroundColor: '#1a1a2e',
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
  },
  physics: {
    default: 'arcade',
    arcade: { gravity: { y: 0 }, debug: false },
  },
  scene: [BootScene, WorldScene, UIScene],
};

window.addEventListener('load', () => {
  new Phaser.Game(config);
});