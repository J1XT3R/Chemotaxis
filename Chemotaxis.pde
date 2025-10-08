Bacteria[] bacteriaArray;
int numBacteria = 20;

Food[] foodSources;
int baseFoodSources = 25;
int numFoodSources;
int foodRespawnTime = 3000;

int generation = 1;
int lastGenerationTime = 0;
int generationDuration = 30000;
float[] fitnessScores;
Bacteria[] nextGeneration;

int foodRequirement = 1;
int survivalCheckInterval = 5;

boolean showDetailedStats = false;

boolean cannibalismEnabled = false;

void setup() {
  size(800, 600);
  background(0);

  createFoodSources();

  bacteriaArray = new Bacteria[numBacteria];
  fitnessScores = new float[numBacteria];
  nextGeneration = new Bacteria[numBacteria];

  for (int i = 0; i < numBacteria; i++) {
    bacteriaArray[i] = new Bacteria();
  }

  lastGenerationTime = millis();
}

void createFoodSources() {
  numFoodSources = max(3, baseFoodSources - (generation - 1) * 2);
  foodSources = new Food[numFoodSources];
  for (int i = 0; i < numFoodSources; i++) {
    foodSources[i] = new Food();
  }
}

void draw() {
  background(0);

  if (millis() - lastGenerationTime > generationDuration) {
    evolveGeneration();
    lastGenerationTime = millis();
  }

  if (!cannibalismEnabled) {
    if (isFoodInsufficient()) enableCannibalismForAll();
  }

  for (int i = 0; i < foodSources.length; i++) {
    foodSources[i].update();
    foodSources[i].show();
  }

  for (int i = 0; i < bacteriaArray.length; i++) {
    bacteriaArray[i].move();
    bacteriaArray[i].show();
    bacteriaArray[i].updateFitness();
  }

  drawGenerationInfo();
}

class Food {
  float x, y;
  float size;
  boolean isConsumed;
  int respawnTimer;
  int foodValue;

  Food() { respawn(); }

  void respawn() {
    x = random(50, width - 50);
    y = random(50, height - 50);
    size = random(8, 15);
    isConsumed = false;
    respawnTimer = 0;
    foodValue = (int)random(5, 15);
  }

  void update() {
    if (isConsumed) {
      respawnTimer++;
      if (respawnTimer > foodRespawnTime) {
        respawn();
      }
    }
  }

  void show() {
    if (!isConsumed) {
      fill(255, 255, 0, 200);
      noStroke();
      ellipse(x, y, size, size);

      fill(255, 255, 0, 50);
      ellipse(x, y, size * 2, size * 2);
    }
  }

  boolean isNearby(float bx, float by, float detectionRadius) {
    if (isConsumed) return false;
    float distance = dist(bx, by, x, y);
    return distance < detectionRadius;
  }

  boolean consume() {
    if (!isConsumed) {
      isConsumed = true;
      respawnTimer = 0;
      return true;
    }
    return false;
  }
}

void evolveGeneration() {
  for (int i = 0; i < bacteriaArray.length; i++) {
    fitnessScores[i] = bacteriaArray[i].getFitness();
  }

  if (generation % survivalCheckInterval == 0) {
    checkSurvival();
    foodRequirement++;
  }

  for (int i = 0; i < bacteriaArray.length; i++) {
    if (bacteriaArray[i].foodConsumed < foodRequirement) {
      bacteriaArray[i].cull();
    }
  }

  int survivors = 0;
  for (int i = 0; i < bacteriaArray.length; i++) {
    if (bacteriaArray[i].foodConsumed >= foodRequirement) {
      survivors++;
    }
  }

  if (survivors < numBacteria / 4) {
    println("EXTINCTION WARNING: survivors " + survivors + "/" + numBacteria);
    enableCannibalismForAll();

    for (int i = 0; i < numBacteria; i++) nextGeneration[i] = new Bacteria();
    bacteriaArray = nextGeneration.clone();
    nextGeneration = new Bacteria[numBacteria];

    for (int i = 0; i < bacteriaArray.length; i++) {
      bacteriaArray[i].onCannibalismEnabledBonus();
      bacteriaArray[i].resetPosition();
    }

    generation++;
    createFoodSources();
    return;
  }

  sortBacteriaByFitness();
  createNextGeneration();

  bacteriaArray = nextGeneration.clone();
  nextGeneration = new Bacteria[numBacteria];

  generation++;
  createFoodSources();

  for (int i = 0; i < bacteriaArray.length; i++) {
    if (bacteriaArray[i].foodConsumed >= foodRequirement) {
      bacteriaArray[i].redistributePoints();
    }
    bacteriaArray[i].resetPosition();
  }
}

void checkSurvival() {
  int survivors = 0;
  int deaths = 0;

  for (int i = 0; i < bacteriaArray.length; i++) {
    if (bacteriaArray[i].foodConsumed >= foodRequirement) survivors++;
    else deaths++;
  }

  println("Generation " + generation + " Survival Check:");
  println("Food Requirement: " + foodRequirement);
  println("Survivors: " + survivors + "/" + bacteriaArray.length);
  println("Deaths: " + deaths);
  println("Survival Rate: " + nf((float)survivors/bacteriaArray.length * 100, 0, 1) + "%");
}

void sortBacteriaByFitness() {
  for (int i = 0; i < bacteriaArray.length - 1; i++) {
    for (int j = 0; j < bacteriaArray.length - i - 1; j++) {
      if (fitnessScores[j] < fitnessScores[j + 1]) {
        Bacteria temp = bacteriaArray[j];
        bacteriaArray[j] = bacteriaArray[j + 1];
        bacteriaArray[j + 1] = temp;

        float tempFitness = fitnessScores[j];
        fitnessScores[j] = fitnessScores[j + 1];
        fitnessScores[j + 1] = tempFitness;
      }
    }
  }
}

void createNextGeneration() {
  int survivors = 0;
  for (int i = 0; i < bacteriaArray.length; i++) {
    if (bacteriaArray[i].foodConsumed >= foodRequirement) survivors++;
  }

  if (survivors == 0) {
    for (int i = 0; i < numBacteria; i++) nextGeneration[i] = new Bacteria();
    return;
  }

  int eliteCount = min(survivors, numBacteria / 2);
  int eliteIndex = 0;

  for (int i = 0; i < bacteriaArray.length && eliteIndex < eliteCount; i++) {
    if (bacteriaArray[i].foodConsumed >= foodRequirement) {
      nextGeneration[eliteIndex] = new Bacteria(bacteriaArray[i]);
      eliteIndex++;
    }
  }

  for (int i = eliteCount; i < numBacteria; i++) {
    Bacteria parent1 = getRandomSurvivor();
    Bacteria parent2 = getRandomSurvivor();
    nextGeneration[i] = new Bacteria(parent1, parent2);
  }

  if (cannibalismEnabled) {
    for (int i = 0; i < numBacteria; i++) {
      nextGeneration[i].onCannibalismEnabledBonus();
    }
  }
}

Bacteria getRandomSurvivor() {
  ArrayList<Bacteria> survivors = new ArrayList<Bacteria>();

  for (int i = 0; i < bacteriaArray.length; i++) {
    if (bacteriaArray[i].foodConsumed >= foodRequirement) {
      survivors.add(bacteriaArray[i]);
    }
  }

  if (survivors.size() > 0) {
    return survivors.get((int)random(survivors.size()));
  } else {
    return bacteriaArray[(int)random(bacteriaArray.length)];
  }
}

boolean isFoodInsufficient() {
  return numFoodSources < max(3, numBacteria / 2);
}

void enableCannibalismForAll() {
  if (cannibalismEnabled) return;
  cannibalismEnabled = true;
  println("Cannibalism ENABLED due to food scarcity.");

  for (int i = 0; i < bacteriaArray.length; i++) {
    bacteriaArray[i].onCannibalismEnabledBonus();
  }
}

void drawGenerationInfo() {
  fill(255);
  textAlign(LEFT);
  textSize(16);

  text("Generation: " + generation, 20, 30);
  text("Food Scarcity: " + nf((1.0 - (float)numFoodSources / baseFoodSources) * 100, 0, 0) + "%", 20, 50);
  text("Cannibalism: " + (cannibalismEnabled ? "ON" : "OFF"), 20, 70);
  text("Click to toggle detailed stats", 20, 90);

  if (showDetailedStats) {
    float bestFitness = 0;
    int bestIndex = 0;
    for (int i = 0; i < bacteriaArray.length; i++) {
      if (bacteriaArray[i].getFitness() > bestFitness) {
        bestFitness = bacteriaArray[i].getFitness();
        bestIndex = i;
      }
    }

    text("Best Fitness: " + nf(bestFitness, 0, 1), 20, 110);
    text("Food Consumed: " + bacteriaArray[bestIndex].foodConsumed, 20, 130);
    text("Survival Requirement: " + foodRequirement + " food", 20, 150);
    text("Food Available: " + numFoodSources, 20, 170);
    text("Next Survival Check: Gen " + ((generation / survivalCheckInterval + 1) * survivalCheckInterval), 20, 190);
    text("Time to next generation: " + ((generationDuration - (millis() - lastGenerationTime)) / 1000) + "s", 20, 210);

    if (bestIndex < bacteriaArray.length) {
      Bacteria best = bacteriaArray[bestIndex];
      text("Best Stats - Speed:" + best.speedLevel + " Acc:" + best.accuracyLevel + " Det:" + best.detectionLevel, 20, 230);
      text("Eff:" + best.efficiencyLevel + " PanicRes:" + best.panicResistanceLevel + " Agg:" + best.aggressionLevel + " Cann:" + best.cannibalisticLevel, 20, 250);
      text("Total Points: " + best.totalStatPoints, 20, 270);
    }

    if (bestIndex < bacteriaArray.length) {
      bacteriaArray[bestIndex].highlightBest();
    }
  }
}

void mousePressed() { showDetailedStats = !showDetailedStats; }

class Bacteria {
  int x, y;
  int bacteriaColor;
  int targetCheckpoint;

  float baseSpeed;
  float baseAccuracy;
  float basePersistence;
  float baseDetectionRadius;

  int speedLevel;
  int accuracyLevel;
  int persistenceLevel;
  int detectionLevel;
  int efficiencyLevel;
  int panicResistanceLevel;
  int aggressionLevel;

  int cannibalisticLevel;

  int statPoints;
  int totalStatPoints;

  int foodConsumed;
  float totalDistance;
  int startTime;
  float energy;
  float fullness;
  boolean isGreedy;

  boolean isPanicking;
  float panicLevel;

  boolean culled;

  Bacteria() {
    x = (int)random(width);
    y = (int)random(height);
    bacteriaColor = color(random(100, 255), random(100, 255), random(100, 255));
    targetCheckpoint = 0;

    baseSpeed = random(0.5, 2.0);
    baseAccuracy = random(0.7, 1.0);
    basePersistence = random(0.1, 0.5);
    baseDetectionRadius = random(30, 80);

    speedLevel = 0;
    accuracyLevel = 0;
    persistenceLevel = 0;
    detectionLevel = 0;
    efficiencyLevel = 0;
    panicResistanceLevel = 0;
    aggressionLevel = 0;
    cannibalisticLevel = 0;

    statPoints = 20;
    totalStatPoints = 20;

    foodConsumed = 0;
    totalDistance = 0;
    startTime = millis();
    energy = 100;
    fullness = 0;
    isGreedy = false;
    isPanicking = false;
    panicLevel = 0.0;

    culled = false;
  }

  Bacteria(Bacteria parent) {
    x = (int)random(width);
    y = (int)random(height);
    bacteriaColor = parent.bacteriaColor;
    targetCheckpoint = 0;

    baseSpeed = parent.baseSpeed + random(-0.1, 0.1);
    baseAccuracy = parent.baseAccuracy + random(-0.05, 0.05);
    basePersistence = parent.basePersistence + random(-0.05, 0.05);
    baseDetectionRadius = parent.baseDetectionRadius + random(-5, 5);

    baseSpeed = constrain(baseSpeed, 0.3, 3.0);
    baseAccuracy = constrain(baseAccuracy, 0.5, 1.0);
    basePersistence = constrain(basePersistence, 0.0, 0.8);
    baseDetectionRadius = constrain(baseDetectionRadius, 20, 100);

    speedLevel = parent.speedLevel;
    accuracyLevel = parent.accuracyLevel;
    persistenceLevel = parent.persistenceLevel;
    detectionLevel = parent.detectionLevel;
    efficiencyLevel = parent.efficiencyLevel;
    panicResistanceLevel = parent.panicResistanceLevel;
    aggressionLevel = parent.aggressionLevel;
    cannibalisticLevel = parent.cannibalisticLevel;

    maybeMutateLevels();

    statPoints = 20;
    totalStatPoints = parent.totalStatPoints;

    foodConsumed = 0;
    totalDistance = 0;
    startTime = millis();
    energy = 100;
    fullness = 0;
    isGreedy = false;
    isPanicking = false;
    panicLevel = 0.0;

    culled = false;
  }

  Bacteria(Bacteria parent1, Bacteria parent2) {
    x = (int)random(width);
    y = (int)random(height);
    bacteriaColor = lerpColor(parent1.bacteriaColor, parent2.bacteriaColor, 0.5);
    targetCheckpoint = 0;

    if (random(1) < 0.5) {
      baseSpeed = parent1.baseSpeed;           baseAccuracy = parent2.baseAccuracy;
      basePersistence = parent1.basePersistence; baseDetectionRadius = parent2.baseDetectionRadius;
    } else {
      baseSpeed = parent2.baseSpeed;           baseAccuracy = parent1.baseAccuracy;
      basePersistence = parent2.basePersistence; baseDetectionRadius = parent1.baseDetectionRadius;
    }

    baseSpeed += random(-0.2, 0.2);
    baseAccuracy += random(-0.1, 0.1);
    basePersistence += random(-0.1, 0.1);
    baseDetectionRadius += random(-10, 10);

    baseSpeed = constrain(baseSpeed, 0.3, 3.0);
    baseAccuracy = constrain(baseAccuracy, 0.5, 1.0);
    basePersistence = constrain(basePersistence, 0.0, 0.8);
    baseDetectionRadius = constrain(baseDetectionRadius, 20, 100);

    if (random(1) < 0.5) {
      speedLevel = parent1.speedLevel;            accuracyLevel = parent2.accuracyLevel;
      persistenceLevel = parent1.persistenceLevel; detectionLevel = parent2.detectionLevel;
      efficiencyLevel = parent1.efficiencyLevel;  panicResistanceLevel = parent2.panicResistanceLevel;
      aggressionLevel = parent1.aggressionLevel;  cannibalisticLevel = parent2.cannibalisticLevel;
    } else {
      speedLevel = parent2.speedLevel;            accuracyLevel = parent1.accuracyLevel;
      persistenceLevel = parent2.persistenceLevel; detectionLevel = parent1.detectionLevel;
      efficiencyLevel = parent2.efficiencyLevel;  panicResistanceLevel = parent1.panicResistanceLevel;
      aggressionLevel = parent2.aggressionLevel;  cannibalisticLevel = parent1.cannibalisticLevel;
    }

    maybeMutateLevels();

    statPoints = 20;
    totalStatPoints = (parent1.totalStatPoints + parent2.totalStatPoints) / 2;

    foodConsumed = 0;
    totalDistance = 0;
    startTime = millis();
    energy = 100;
    fullness = 0;
    isGreedy = false;
    isPanicking = false;
    panicLevel = 0.0;

    culled = false;
  }

  void maybeMutateLevels() {
    if (random(100) < 5) {
      String[] traits = {"speed", "accuracy", "persistence", "detection", "efficiency", "panicResistance", "aggression", "cannibalistic"};
      String trait = traits[(int)random(traits.length)];
      if (random(100) < 50) decTrait(trait);
      else incTrait(trait);
    }
  }

  void decTrait(String trait) {
    switch(trait) {
      case "speed": if (speedLevel > 0) speedLevel--; break;
      case "accuracy": if (accuracyLevel > 0) accuracyLevel--; break;
      case "persistence": if (persistenceLevel > 0) persistenceLevel--; break;
      case "detection": if (detectionLevel > 0) detectionLevel--; break;
      case "efficiency": if (efficiencyLevel > 0) efficiencyLevel--; break;
      case "panicResistance": if (panicResistanceLevel > 0) panicResistanceLevel--; break;
      case "aggression": if (aggressionLevel > 0) aggressionLevel--; break;
      case "cannibalistic": if (cannibalisticLevel > 0) cannibalisticLevel--; break;
    }
  }

  void incTrait(String trait) {
    switch(trait) {
      case "speed": if (speedLevel < 5) speedLevel++; break;
      case "accuracy": if (accuracyLevel < 5) accuracyLevel++; break;
      case "persistence": if (persistenceLevel < 5) persistenceLevel++; break;
      case "detection": if (detectionLevel < 5) detectionLevel++; break;
      case "efficiency": if (efficiencyLevel < 5) efficiencyLevel++; break;
      case "panicResistance": if (panicResistanceLevel < 5) panicResistanceLevel++; break;
      case "aggression": if (aggressionLevel < 5) aggressionLevel++; break;
      case "cannibalistic": if (cannibalisticLevel < 5) cannibalisticLevel++; break;
    }
  }

  void onCannibalismEnabledBonus() {
    statPoints += 2;
    totalStatPoints += 2;
  }

  void cull() { culled = true; }

  void move() {
    if (culled) return;

    energy -= 0.1;
    if (energy < 0) energy = 0;

    if (random(100) < 5) isGreedy = !isGreedy;

    fullness -= 0.05;
    if (fullness < 0) fullness = 0;

    updatePanicLevel();

    Food nearestFood = null;
    float currentDetectionRadius = getEffectiveDetectionRadius();
    if (isPanicking) currentDetectionRadius *= (1 + panicLevel * 2);

    float nearestFoodDistance = currentDetectionRadius;

    for (int i = 0; i < foodSources.length; i++) {
      if (foodSources[i].isNearby(x, y, currentDetectionRadius)) {
        float distance = dist(x, y, foodSources[i].x, foodSources[i].y);
        if (distance < nearestFoodDistance) {
          nearestFood = foodSources[i];
          nearestFoodDistance = distance;
        }
      }
    }

    Bacteria nearestPrey = null;
    float nearestPreyDistance = currentDetectionRadius;
    boolean considerCannibalism = cannibalismEnabled && cannibalisticLevel > 0 &&
                                  (foodConsumed < foodRequirement || nearestFood == null || nearestFoodDistance > 0.6 * currentDetectionRadius);

    if (considerCannibalism) {
      for (int i = 0; i < bacteriaArray.length; i++) {
        Bacteria other = bacteriaArray[i];
        if (other == this || other.culled) continue;
        float d = dist(x, y, other.x, other.y);
        if (d < nearestPreyDistance) {
          if (this.getAggression() + getCannibalEdge() >= other.getAggression() || d < 12) {
            nearestPrey = other;
            nearestPreyDistance = d;
          }
        }
      }
    }

    float randomAngle = random(TWO_PI);
    float energyFactor = max(energy / 100, 0.5);
    float baseMoveSpeed = 2 * getEffectiveSpeed() * energyFactor * getEfficiencyBonus();
    if (isPanicking) baseMoveSpeed *= (1 + panicLevel * 1.5);
    if (fullness > 100 && !isPanicking) baseMoveSpeed *= 0.5;
    baseMoveSpeed = max(baseMoveSpeed, 1.0);

    float randomDx = cos(randomAngle) * baseMoveSpeed;
    float randomDy = sin(randomAngle) * baseMoveSpeed;

    boolean chasePrey = (nearestPrey != null) && (nearestFood == null || nearestPreyDistance < nearestFoodDistance * 0.8);

    if (chasePrey) {
      float dx = nearestPrey.x - x;
      float dy = nearestPrey.y - y;
      float distance = sqrt(dx*dx + dy*dy);

      if (distance > 0) {
        dx /= distance; dy /= distance;
        float chaseSpeed = 3.2 * getEffectiveSpeed() * energyFactor * getEfficiencyBonus() * (1 + 0.15 * cannibalisticLevel);
        if (isPanicking) chaseSpeed *= (1 + panicLevel * 1.2);
        chaseSpeed = max(chaseSpeed, 1.3);

        float randomFactor = getEffectivePersistence() * random(-2, 2);
        float acc = getEffectiveAccuracy();

        float chaseDx = (dx * chaseSpeed * acc) + randomFactor;
        float chaseDy = (dy * chaseSpeed * acc) + randomFactor;

        float randomRatio = isPanicking ? (0.25 + panicLevel * 0.2) : 0.5;
        float chaseRatio = 1.0 - randomRatio;

        randomDx = randomDx * randomRatio + chaseDx * chaseRatio;
        randomDy = randomDy * randomRatio + chaseDy * chaseRatio;

        if (distance < 10) {
          float winChance = 0.5f + 0.1f * cannibalisticLevel + 0.1f * (getAggression() - nearestPrey.getAggression());
          if (random(1) < constrain(winChance, 0.1, 0.95)) {
            if (!nearestPrey.culled) {
              nearestPrey.cull();
              foodConsumed++;
              energy = min(100, energy + 35);
              fullness = min(200, fullness + 25);
            }
          }
        }
      }
    } else if (nearestFood != null) {
      float dx = nearestFood.x - x;
      float dy = nearestFood.y - y;
      float distance = sqrt(dx*dx + dy*dy);

      totalDistance += distance;

      if (distance > 0) {
        dx /= distance; dy /= distance;

        float foodSeekSpeed = 3 * getEffectiveSpeed() * energyFactor * getEfficiencyBonus();
        if (isPanicking) foodSeekSpeed *= (1 + panicLevel * 2);
        if (fullness > 100 && !isPanicking) foodSeekSpeed *= 0.6;
        foodSeekSpeed = max(foodSeekSpeed, 1.2);

        float randomFactor = getEffectivePersistence() * random(-2, 2);
        float accuracyFactor = getEffectiveAccuracy();
        if (fullness > 100) accuracyFactor *= 0.7;

        float foodSeekDx = (dx * foodSeekSpeed * accuracyFactor) + randomFactor;
        float foodSeekDy = (dy * foodSeekSpeed * accuracyFactor) + randomFactor;

        float randomRatio = isPanicking ? (0.3 + panicLevel * 0.2) : 0.6;
        float foodRatio = 1.0 - randomRatio;

        randomDx = randomDx * randomRatio + foodSeekDx * foodRatio;
        randomDy = randomDy * randomRatio + foodSeekDy * foodRatio;

        if (distance < 15) {
          if (nearestFood.consume()) {
            foodConsumed++;
            energy = min(100, energy + 20);
            fullness = min(200, fullness + (isGreedy ? 25 : 15));
          }
        }
      }
    }

    int moveX = (int)randomDx;
    int moveY = (int)randomDy;
    if (moveX == 0 && moveY == 0) {
      moveX = (randomDx > 0) ? 1 : -1;
      moveY = (randomDy > 0) ? 1 : -1;
    }

    int newX = x + moveX;
    int newY = y + moveY;

    Bacteria collidedWith = checkCollision(newX, newY);
    if (collidedWith == null) {
      x = newX; y = newY;
    } else {
      float myAggression = getAggression();
      float theirAggression = collidedWith.getAggression();
      float myEdge = getCannibalEdge();

      if (myAggression + myEdge > theirAggression) {
        x = newX; y = newY;
        pushBacteriaAway(collidedWith, newX, newY);
      } else if (myAggression + myEdge == theirAggression && random(100) < 50) {
        x = newX; y = newY;
        pushBacteriaAway(collidedWith, newX, newY);
      } else {
        float angle = atan2(moveY, moveX) + random(-PI/2, PI/2);
        int altMoveX = (int)(cos(angle) * abs(moveX));
        int altMoveY = (int)(sin(angle) * abs(moveY));

        Bacteria altCollision = checkCollision(x + altMoveX, y + altMoveY);
        if (altCollision == null) {
          x += altMoveX; y += altMoveY;
        } else if (myAggression + myEdge > altCollision.getAggression()) {
          x += altMoveX; y += altMoveY;
          pushBacteriaAway(altCollision, x, y);
        }
      }
    }

    x = constrain(x, 0, width);
    y = constrain(y, 0, height);
  }

  void updateFitness() { }

  float getFitness() {
    float foodScore = foodConsumed * 50;
    float energyScore = energy;
    float efficiencyScore = (foodConsumed > 0) ? (foodConsumed * 100) / max(1, totalDistance) : 0;
    float cannibalScore = cannibalisticLevel * 10;
    return foodScore + energyScore + efficiencyScore + cannibalScore;
  }

  void resetPosition() {
    x = (int)random(width);
    y = (int)random(height);
    targetCheckpoint = 0;
    foodConsumed = 0;
    totalDistance = 0;
    startTime = millis();
    energy = 100;
    fullness = 0;
    isGreedy = false;
    isPanicking = false;
    panicLevel = 0.0;
    culled = false;
  }

  float getEffectiveSpeed() { return baseSpeed * (1 + speedLevel * 0.2); }
  float getEffectiveAccuracy() { return min(1.0, baseAccuracy + accuracyLevel * 0.05); }
  float getEffectivePersistence() { return basePersistence + persistenceLevel * 0.1; }
  float getEffectiveDetectionRadius() { return baseDetectionRadius * (1 + detectionLevel * 0.3); }
  float getEfficiencyBonus() { return 1 + efficiencyLevel * 0.15; }
  float getPanicResistance() { return panicResistanceLevel * 0.2; }
  float getAggression() { return aggressionLevel * 0.2; }
  float getCannibalEdge() { return cannibalisticLevel * 0.2; }

  boolean investInTrait(String traitName) {
    if (statPoints <= 0) return false;
    switch(traitName) {
      case "speed": if (speedLevel < 5) { speedLevel++; statPoints--; return true; } break;
      case "accuracy": if (accuracyLevel < 5) { accuracyLevel++; statPoints--; return true; } break;
      case "persistence": if (persistenceLevel < 5) { persistenceLevel++; statPoints--; return true; } break;
      case "detection": if (detectionLevel < 5) { detectionLevel++; statPoints--; return true; } break;
      case "efficiency": if (efficiencyLevel < 5) { efficiencyLevel++; statPoints--; return true; } break;
      case "panicResistance": if (panicResistanceLevel < 5) { panicResistanceLevel++; statPoints--; return true; } break;
      case "aggression": if (aggressionLevel < 5) { aggressionLevel++; statPoints--; return true; } break;
      case "cannibalistic": if (cannibalisticLevel < 5 && cannibalismEnabled) { cannibalisticLevel++; statPoints--; return true; } break;
    }
    return false;
  }

  void autoInvestPoints() {
    String[] traits = cannibalismEnabled
      ? new String[]{"detection", "speed", "efficiency", "accuracy", "panicResistance", "persistence", "aggression", "cannibalistic"}
      : new String[]{"detection", "speed", "efficiency", "accuracy", "panicResistance", "persistence", "aggression"};

    while (statPoints > 0) {
      String chosenTrait = traits[(int)random(traits.length)];
      if (!investInTrait(chosenTrait)) {
        boolean invested = false;
        for (String trait : traits) {
          if (investInTrait(trait)) { invested = true; break; }
        }
        if (!invested) break;
      }
    }
  }

  void redistributePoints() {
    int totalInvested = speedLevel + accuracyLevel + persistenceLevel + detectionLevel +
                        efficiencyLevel + panicResistanceLevel + aggressionLevel + cannibalisticLevel;

    speedLevel = accuracyLevel = persistenceLevel = detectionLevel = 0;
    efficiencyLevel = panicResistanceLevel = aggressionLevel = 0;
    cannibalisticLevel = 0;

    statPoints = totalInvested;
    redistributeBasedOnPerformance();
  }

  void redistributeBasedOnPerformance() {
    String[] preferredTraits = analyzeNeededTraits();
    while (statPoints > 0) {
      String chosenTrait;
      if (random(100) < 70 && preferredTraits.length > 0) {
        chosenTrait = preferredTraits[(int)random(preferredTraits.length)];
      } else {
        String[] allTraits = cannibalismEnabled
          ? new String[]{"speed", "accuracy", "detection", "efficiency", "panicResistance", "persistence", "aggression", "cannibalistic"}
          : new String[]{"speed", "accuracy", "detection", "efficiency", "panicResistance", "persistence", "aggression"};
        chosenTrait = allTraits[(int)random(allTraits.length)];
      }

      if (!investInTrait(chosenTrait)) {
        boolean invested = false;
        String[] allTraits = cannibalismEnabled
          ? new String[]{"speed", "accuracy", "detection", "efficiency", "panicResistance", "persistence", "aggression", "cannibalistic"}
          : new String[]{"speed", "accuracy", "detection", "efficiency", "panicResistance", "persistence", "aggression"};
        for (String trait : allTraits) {
          if (investInTrait(trait)) { invested = true; break; }
        }
        if (!invested) break;
      }
    }
  }

  String[] analyzeNeededTraits() {
    ArrayList<String> neededTraits = new ArrayList<String>();

    if (foodConsumed < foodRequirement) {
      neededTraits.add("detection");
      neededTraits.add("speed");
      neededTraits.add("aggression");
      if (cannibalismEnabled) neededTraits.add("cannibalistic");
    }
    if (panicLevel > 0.5) neededTraits.add("panicResistance");
    if (totalDistance > 1000 && foodConsumed < 3) {
      neededTraits.add("efficiency"); neededTraits.add("accuracy");
    }
    if (foodConsumed > 0 && totalDistance < 500) neededTraits.add("aggression");
    if (foodConsumed < 2 && totalDistance > 800) {
      neededTraits.add("accuracy"); neededTraits.add("persistence");
    }

    String[] result = new String[neededTraits.size()];
    for (int i = 0; i < neededTraits.size(); i++) result[i] = neededTraits.get(i);
    return result;
  }

  void updatePanicLevel() {
    if (foodConsumed < foodRequirement) {
      int timeElapsed = millis() - lastGenerationTime;
      int timeRemaining = generationDuration - timeElapsed;
      float scarcityFactor = 1.0 - (float)numFoodSources / baseFoodSources;

      if (timeRemaining > 0) {
        float timePanic = 1.0 - (float)timeRemaining / generationDuration;
        float scarcityPanic = scarcityFactor * 0.5;
        panicLevel = (timePanic + scarcityPanic) * (1 - getPanicResistance());
        isPanicking = panicLevel > 0.2;
      } else {
        panicLevel = (1.0 + scarcityFactor * 0.5) * (1 - getPanicResistance());
        isPanicking = true;
      }
    } else {
      panicLevel = 0.0; isPanicking = false;
    }
  }

  Bacteria checkCollision(int newX, int newY) {
    for (int i = 0; i < bacteriaArray.length; i++) {
      if (bacteriaArray[i] != this && !bacteriaArray[i].culled) {
        float distance = dist(newX, newY, bacteriaArray[i].x, bacteriaArray[i].y);
        if (distance < 16) return bacteriaArray[i];
      }
    }
    return null;
  }

  void pushBacteriaAway(Bacteria other, int myX, int myY) {
    float dx = other.x - myX;
    float dy = other.y - myY;
    float distance = sqrt(dx*dx + dy*dy);

    if (distance > 0) {
      dx /= distance; dy /= distance;
      int pushDistance = 2;
      int newOtherX = other.x + (int)(dx * pushDistance);
      int newOtherY = other.y + (int)(dy * pushDistance);

      Bacteria otherCollision = other.checkCollision(newOtherX, newOtherY);
      if (otherCollision == null || other.getAggression() > otherCollision.getAggression()) {
        other.x = constrain(newOtherX, 0, width);
        other.y = constrain(newOtherY, 0, height);
      }
    }
  }

  void highlightBest() {
    if (culled) return;
    stroke(255, 215, 0);
    strokeWeight(3);
    noFill();
    ellipse(x, y, 15, 15);
  }

  void show() {
    if (culled) return;

    float energyFactor = energy / 100;
    color displayColor = lerpColor(bacteriaColor, color(255, 0, 0), 1 - energyFactor);

    if (isPanicking) {
      float pulse = sin(millis() * 0.01) * 0.3 + 0.7;
      displayColor = lerpColor(displayColor, color(255, 0, 0), panicLevel * pulse);
    }

    fill(displayColor);
    noStroke();
    ellipse(x, y, 8, 8);

    if (isPanicking) {
      float pulse = sin(millis() * 0.02) * 0.5 + 0.5;
      stroke(255, 0, 0, 100 + panicLevel * 155);
      strokeWeight(2 + panicLevel * 2);
      noFill();
      ellipse(x, y, 12 + panicLevel * 8, 12 + panicLevel * 8);
    }

    if (fullness > 100) {
      float bloatFactor = 1 + (fullness - 100) / 100;
      fill(displayColor, 150);
      ellipse(x, y, 8 * bloatFactor, 8 * bloatFactor);

      if (isGreedy) {
        fill(255, 255, 0, 100);
        ellipse(x, y, 12 * bloatFactor, 12 * bloatFactor);
      }
    }

    if (foodConsumed >= foodRequirement) {
      stroke(0, 255, 0, 150);
    } else {
      stroke(255, 0, 0, 150);
    }
    strokeWeight(2);
    noFill();
    ellipse(x, y, 12, 12);

    if (cannibalisticLevel > 0 && cannibalismEnabled) {
      stroke(180, 0, 255, 160);
      strokeWeight(1);
      noFill();
      ellipse(x, y, 16, 16);
    }
  }
}
