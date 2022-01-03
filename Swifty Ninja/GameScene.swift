//
//  GameScene.swift
//  Swifty Ninja
//
//  Created by Phat Nguyen on 31/12/2021.
//

import SpriteKit
import AVFoundation

enum ForceBomb {
    case never, always, random
}

enum SequenceType: CaseIterable {
    case oneNoBomb, one, twoWithOneBomb, two, three, four, chain, fastChain
}

class GameScene: SKScene {
    
    var gameScores: SKLabelNode!
    var bombSoundEffect: AVAudioPlayer?
    
    var livesImages = [SKSpriteNode]()
    var activeEnemies = [SKSpriteNode]()
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    
    var activeSlicePoints = [CGPoint]()
    var lives = 3
    var isSwooshSoundActive = false
    var scores = 0 {
        didSet {
            gameScores.text = "Scores: \(scores)"
        }
    }
    
    var popupTime = 0.9
    var sequence = [SequenceType]()
    var sequencePosition = 0
    var chainDelay = 3.0
    var nextSequenceQueued = true
    
    override func didMove(to view: SKView) {
        background()
        physicWorld()
        
        // setup Game
        createScore()
        createLives()
        createSlices()
        
        // start Game
        startGame()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        // play sound effect
        if !isSwooshSoundActive {
            playSwooshSound()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // remove all activeSlicePoints
        activeSlicePoints.removeAll()
        
        // add new location array and show the slices
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        // show slice
        redrawActiveSlice()
        
        // Remove any actions that are currently attached to the slice shapes. This will be important if they are in the middle of a fadeOut(withDuration:) action.
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        // give alpha =1 bc fadeOut can do it invisible
        activeSliceBG.alpha = 1
        activeSliceFG.alpha = 1
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // fade out the slices
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func update(_ currentTime: TimeInterval) {
        removeEnimesFallOffScreen()
        
        var bombCount = 0
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
    }
    
    func background() {
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
    }
    
    func physicWorld() {
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        physicsWorld.speed = 0.85
    }
    
    func startGame() {
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        for _ in 0...1000 {
            if let nextSequence = SequenceType.allCases.randomElement() {
                sequence.append(nextSequence)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            [weak self] in self?.tossEnemies()
        }
    }
    
    func createScore() {
        // show the scores label by the bottom left screen
        gameScores = SKLabelNode(fontNamed: "Chalkduster")
        gameScores.horizontalAlignmentMode = .left
        gameScores.fontSize = 48
        gameScores.position = CGPoint(x: 8, y: 8)
        scores = 0
        addChild(gameScores)
    }
    
    func createLives() {
        // append 3 sliceLife into array and show it by the top right screen
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + i*70), y: 720)
            addChild(spriteNode)
            
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        activeSliceBG = SKShapeNode()
        activeSliceBG.strokeColor = UIColor(red: 1.0, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.strokeColor = .white
        activeSliceFG.lineWidth = 5
        activeSliceFG.zPosition = 3
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    func redrawActiveSlice() {
        if activeSlicePoints.count < 2 {
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        // if > 12 location, remove first redundancy location in array.
        if activeSlicePoints.count > 12 {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
        }
        
        // draw the line
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        
        // follow the path
        for i in 1 ..< activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        // assign path to active
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    
    func playSwooshSound() {
        // set value = true and random the sound in .caf file
        isSwooshSoundActive = true
        
        let randomNumber = Int.random(in: 1...3)
        let soundName = "swoosh\(randomNumber).caf"
        
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        
        run(swooshSound) {
            [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.isSwooshSoundActive = false
        }
    }
    
    func createEnemy(forceBomb: ForceBomb = .random) {
        let enemy: SKSpriteNode
        
        var enemyType = Int.random(in: 0...6)
        
        if forceBomb == .always {
            enemyType = 0
        } else if forceBomb == .never {
            enemyType = 1
        }
        
        
        if enemyType == 0 {
            // bomb
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage)
            
            if bombSoundEffect != nil {
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
                if let sound = try? AVAudioPlayer(contentsOf: path) {
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
                emitter.position = CGPoint(x: 76, y: 64)
                enemy.addChild(emitter)
            }
        }
        else {
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy"
        }
        
        /**
         1 Give the enemy a random position off the bottom edge of the screen.
         2 Create a random angular velocity, which is how fast something should spin.
         3 Create a random X velocity (how far to move horizontally) that takes into account the enemy's position.
         4 Create a random Y velocity just to make things fly at different speeds.
         5 Give all enemies a circular physics body where the collisionBitMask is set to 0 so they don't collide.
        */
        
        // 1
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
        enemy.position = randomPosition
        
        // 2
        let randomAngularVelocity = CGFloat.random(in: -3...3 )
        let randomXVelocity: Int
        
        // 3
        if randomPosition.x < 256 {
            randomXVelocity = Int.random(in: 8...15)
        } else if randomPosition.x < 512 {
            randomXVelocity = Int.random(in: 3...5)
        } else if randomPosition.x < 768 {
            randomXVelocity = -Int.random(in: 3...5)
        } else {
            randomXVelocity = -Int.random(in: 8...15)
        }

        // 4
        let randomYVelocity = Int.random(in: 24...32)
        
        // 5
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64)
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0
        
        addChild(enemy)
        activeEnemies.append(enemy)
        
    }
    
    func tossEnemies() {
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        let sequenceType = sequence[sequencePosition]
        
        switch sequenceType {
        case .oneNoBomb:
            createEnemy(forceBomb: .never)
        case .one:
            createEnemy()
        case .twoWithOneBomb:
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
        case .two:
            createEnemy()
            createEnemy()
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
        case .chain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) { [weak self] in self?.createEnemy() }
        case .fastChain:
            createEnemy()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) { [weak self] in self?.createEnemy() }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) { [weak self] in self?.createEnemy() }
        }
        
        sequencePosition += 1
        nextSequenceQueued = false
    }
    
    func removeEnimesFallOffScreen() {
        if activeEnemies.count > 0 {
            for (index, node) in activeEnemies.enumerated().reversed() {
                if node.position.y < -140 {
                    node.removeFromParent()
                    activeEnemies.remove(at: index)
                }
            }
        } else {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [weak self] in
                    self?.tossEnemies()
                }
                
                nextSequenceQueued = true
            }
        }
    }
}
