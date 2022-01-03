//
//  ViewController.swift
//  AwaitDemo
//
//  Created by aa on 2021/9/23.
//
//  参考：
//  1.Swift_并发初步：https://onevcat.com/2021/07/swift-concurrency
//  2.Swift_结构化并发：https://onevcat.com/2021/09/structured-concurrency
//

// MARK: - 异步函数的注意点
/*
 * 1.如果是在`另一个异步函数`或者`子Task`内调用该异步函数：执行完之后还是在被await分配到的线程中（子线程）
 * 2.如果是在`父Task`内调用该异步函数：执行完之后会回到调用该函数的那个线程（一般是主线程）
 
 * 🌰🌰🌰 假设Task的执行环境是在主线程：
 Task {
     // ------ 此处是：主线程 ------
     
     await withTaskGroup(of: String.self) { group in
         group.addTask(priority: .low) {
 
             // ------ 此处是：新的子线程 ------
             let str = await self.getHitokoto(1)
             // ------ 此处是：`getHitokoto`内分配的子线程 ------
 
             ///【在`子Task`中调用async函数，执行完之后还仍旧处于那个async函数所在的线程】
             return str
         }
         // ......
     }
     // ====== 等到`TaskGroup`执行完再继续下面代码 ======
     
     // ------ 此处是：主线程 ------
     // ......

     let str3 = await getHitokoto(3)
     // ====== 等到`getHitokoto`执行完再继续下面代码 ======
     // ------ 此处是：主线程 ------
 
     /// 跟`TaskGroup`里面的子任务不同，【在`Task`中调用async函数，执行完之后会回到调用async函数时的线程】
 
     // ......
 }

 // async函数
 func getHitokoto(_ tag: Int, delay: UInt64 = 0) async -> String {

     // ------ 此处是：调用该函数时的线程，可能是主线程也可能是子线程 ------

     let (data, _) = try? await URLSession.shared.data(from: URL(string: "https://v1.hitokoto.cn")!)
     // ====== 等到服务器响应再继续下面代码 ======

     // ------ 此处是：因`await`而被底层机制分配到其他合适的线程 ------
     ///【在`异步函数`中调用async函数，执行完之后还仍旧处于那个async函数所在的线程】

     var str = "null"
     if let json = try? JSONSerialization.jsonObject(with: data!, options: .mutableContainers),
        let dic = json as? [String: Any],
        let hitokoto = dic["hitokoto"] as? String {
         str = hitokoto
     }
     return str
 }
 
 */
 
import UIKit

class ViewController: UIViewController {
    let tv: UITextView = UITextView()
    let imgView = UIImageView()
    
    let uHolder = UnsafeHolder()
    let sHolder = SafeHolder()
    let aHolder = ActorHolder()
    
    var hType = HolderType.unsafe
    var maxCount = 0
    var curCount = 0
    
    var btnW: CGFloat { 80 }
    var btnH: CGFloat { 60 }
    func btnX(_ col: Int) -> CGFloat { 20 + CGFloat(col) * (btnW + 15) }
    func btnY(_ row: Int) -> CGFloat { 100 + CGFloat(row) * (btnH + 15) }
    func buildBtn(withIndex index: Int, action: Selector) -> UIButton {
        let col = index % 3
        let row = index / 3
        let btn: UIButton = {
            let b = UIButton(type: .system)
            b.setTitle("🌰.\(index + 1)", for: .normal)
            b.setTitleColor(.randomColor, for: .normal)
            b.backgroundColor = .randomColor
            b.frame = [btnX(col), btnY(row), btnW, btnH]
            b.addTarget(self, action: action, for: .touchUpInside)
            return b
        }()
        view.addSubview(btn)
        return btn
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .randomColor
        
        var lastBtnMaxY: CGFloat = 0
        for (i, action) in exampleActions.enumerated() {
            lastBtnMaxY = buildBtn(withIndex: i, action: action).frame.maxY
        }
        
        let tvLabel = UILabel(frame: [20, lastBtnMaxY + 20, 400, 20])
        tvLabel.font = .boldSystemFont(ofSize: 15)
        tvLabel.textColor = .randomColor
        tvLabel.text = "用来看有木有阻塞主线程（运行时来回拖动）"
        view.addSubview(tvLabel)
        
        tv.frame = [tvLabel.x, tvLabel.maxY, 300, 150]
        tv.backgroundColor = .randomColor
        tv.text = longStr
        view.addSubview(tv)
        
        imgView.frame = [tv.x, tv.maxY + 20, 300, 200]
        imgView.backgroundColor = .randomColor
        imgView.contentMode = .scaleAspectFit
        view.addSubview(imgView)
    }
}

extension ViewController {
    // MARK: - 公共API：异步获取网络数据
    @discardableResult
    func getHitokoto(_ tag: Int, delay: UInt64 = 0) async -> String {
        JPrint("\(String(format: "%02d", tag)) - getHitokoto_begin", Thread.current)
        
        if delay > 0 {
            await Task.sleep(delay * NSEC_PER_SEC)
            JPrint("\(String(format: "%02d", tag)) - getHitokoto_afterSleep", Thread.current)
        }
        
        var str = "null"
        if let url = URL(string: "https://v1.hitokoto.cn"),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
           let dic = json as? [String: Any],
           let hitokoto = dic["hitokoto"] as? String {
            str = hitokoto
        }
        
        JPrint("\(String(format: "%02d", tag)) - getHitokoto_end", str, Thread.current)
        return str
    }
    
    // MARK: - 公共API：自己写的耗时同步函数
    @discardableResult
    func timeConsuming() async -> String {
        JPrint("timeConsuming_begin \(Thread.current)")
        for _ in 0 ..< 9999999 {
            
        }
        JPrint("timeConsuming_end \(Thread.current)")
        return "hi"
    }
}

// MARK: - 🌰1.异步函数初体验
/// 有`async`标识的函数，都会在对应的`Task`上下文环境中执行。
extension ViewController {
    @objc func btn1DidClick() {
        JPrint("btn1DidClick")
        
        JPrint("111 \(Thread.current)")
        
        Task {
            
            JPrint("222 \(Thread.current)")
            
            do {
                let str1 = try await loadData(0)
                JPrint("str1 \(str1) \(Thread.current)") // 回到调用函数的那个线程（主线程）
                tv.backgroundColor = .randomColor

                let str2 = try await loadData(1)
                JPrint("str2 \(str2) \(Thread.current)") // 回到调用函数的那个线程（主线程）
                tv.backgroundColor = .randomColor

                let str3 = try await loadData(2)
                JPrint("str3 \(str3) \(Thread.current)") // 回到调用函数的那个线程（主线程）
                tv.backgroundColor = .randomColor
                
                // 这个Task由于是在上面的全部await之后才开始的，所以要等外层的Task全部执行完（也就是“555”之后）才执行
                Task {
                    JPrint("333 \(Thread.current)")
                    let str4 = try await loadData(3)
                    JPrint("str4 \(str4) \(Thread.current)")
                    tv.backgroundColor = .randomColor
                }

                JPrint("444 \(Thread.current)")
                
            } catch {
                JPrint("error \(error)")
            }

            JPrint("555 \(Thread.current)")
        }
        
        // 这个Task跟上面的Task是并发执行的
        Task {
            JPrint("666 \(Thread.current)")
            let str5 = await getHitokoto(4)
            JPrint("str5 \(str5) \(Thread.current)") // 回到调用函数的那个线程（主线程）
            tv.backgroundColor = .randomColor
        }
        
        JPrint("777 \(Thread.current)")
        
//        Task {
//            await withTaskGroup(of: String.self) { taskGroup in
//                taskGroup.addTask(priority: .low) {
//                    JPrint("t1 ---", Thread.current)
//                    return await self.loadData222()
//                }
//
//                taskGroup.addTask(priority: .low) {
//                    JPrint("t2 ---", Thread.current)
//                    return await self.loadData222()
//                }
//
//                await taskGroup.waitForAll()
//
//                taskGroup.addTask(priority: .low) {
//                    JPrint("t3 ---", Thread.current)
//                    return await self.loadData222()
//                }
//
//                for await r in taskGroup {
//                    JPrint("r ---", r)
//                }
//            }
//        }
    }
    
    // 异步函数
    // 1.如果是在`另一个异步函数`或者`子Task`内调用该异步函数：执行完之后还是在被await分配到的线程中（子线程）
    // 2.如果是在`父Task`内调用该异步函数：执行完之后会回到调用该函数的那个线程（主线程）
    func loadData(_ tag: Int) async throws -> String {
        JPrint("\(tag) - loadData_1 \(Thread.current)") // *** 调用函数的那个线程（主线程）***
        
        // ------- 此时是调用函数时的那个线程 -------
        
        let str1 = await getHitokoto(tag * 10 + 1) // await - 代表了函数在此处会放弃当前线程，将被底层机制分配到其他合适的线程，也就是函数此处被【暂停】了
        
        /**
         * 放弃线程的能力，意味着异步方法可以被【暂停】，这个线程可以被用来执行其他代码。
         * 如果这个线程是【主线程】的话，函数在此处【暂停】，主线程则去处理其他事情，因此界面不会卡顿。
         */
        
        // 来到这里时，说明上面await代码执行完了，函数继续执行，只不过此时不再是执行await代码前的那个线程了。
        // 因为该函数本身就是异步函数，所以此时还是在上面await代码内被await分配到的线程中（子线程）
        
        // ------- 此时是被await分配到的线程 -------
        
        JPrint("\(tag) - loadData_2 \(str1), \(Thread.current)") // *** 第一个`getHitokoto`内分配的子线程 ***
        
        let str2 = await getHitokoto(tag * 10 + 2, delay: 1)
        
        JPrint("\(tag) - loadData_3 \(str2), \(Thread.current)") // *** 第二个`getHitokoto`内分配的子线程 ***
        // PS：有空闲的线程则会用旧的线程
        
        return "\(tag) - \(str1) +++ \(str2)"

    }
    
//    func loadData222() async -> String {
//        var str = ""
//        do {
//            str = try await loadData(0)
//        } catch {
//            str = "error"
//        }
//        return str
//    }
}

// MARK: - 🌰2.使用`async let`把自己写的【复杂耗时的同步函数】丢到子线程里面异步执行
extension ViewController {
    @objc func btn2DidClick() {
        JPrint("btn2DidClick")
        
        JPrint("111 \(Thread.current)")
        Task {
            JPrint("222 \(Thread.current)")
            
            /// `timeConsuming()`是个同步函数，里面代码都是同步执行的（没有`await`其他函数）
            /// 因此调用`timeConsuming()`只会在当前线程里面同步执行，会卡住当前线程
            /// 在异步函数`test1()`中通过`async let`可以把`timeConsuming()`里面的代码丢到子线程执行
            /// 可以通过这种方式把【复杂耗时的同步函数】丢到子线程里面异步执行
            let str = await test1()
            
            JPrint("333 \(str) \(Thread.current)") // 回到调用函数的那个线程（主线程）
            tv.backgroundColor = .randomColor
        }
        
        JPrint("444 \(Thread.current)")
    }
    
    func test1() async -> String {
        /// 通过`async let`可以把`timeConsuming()`里面的代码丢到子线程执行
        /// `async let` 被称为异步绑定，它在当前`Task` 上下文中创建新的子任务，并将它用作被绑定的异步函数的运行环境。
        /// 被异步绑定的操作会立即开始执行，即使在`await`之前执行就已经完成，其结果依然可以等到`await`语句时再进行求值。
        async let str = timeConsuming()
        
        /// 测试：延迟个8s，test1都执行完了，str还是不为所动，只会等到`await`语句时再进行求值
        JPrint("go to sleep \(Thread.current)") // 调用函数的那个线程（主线程）
        await Task.sleep(8 * NSEC_PER_SEC) // 不会阻塞调用函数的线程（主线程），而是来到了异步执行`timeConsuming()`的那个线程
        JPrint("sleep over \(Thread.current)") // 子线程
        
        return await str // 在这里才会求值（timeConsuming的返回值）
    }
}

// MARK: - 🌰3.使用`async let`并发执行【多个】异步函数
extension ViewController {
    @objc func btn3DidClick() {
        JPrint("btn3DidClick")
        
        JPrint("111 \(Thread.current)")
        
        Task {
            JPrint("222 \(Thread.current)")
            
            _ = await test3()
            
            JPrint("333 \(Thread.current)") // 回到调用函数的那个线程（主线程）
            tv.backgroundColor = .randomColor
        }
        
        JPrint("444 \(Thread.current)")
    }
    
    func test3() async -> String {
        
        async let value1 = getHitokoto(1111)
        async let value2 = getHitokoto(2222)
        
        /// 测试：延迟个8s，test1都执行完了，str还是不为所动，只会等到`await`语句时再进行求值
        JPrint("go to sleep \(Thread.current)") // 调用函数的那个线程（主线程）
        await Task.sleep(8 * NSEC_PER_SEC) // 不会阻塞调用函数的线程（主线程），而是异步回来时的那个线程，例如如果执行`getHitokoto(1111)`完成比`getHitokoto(2222)`慢，最后来到这里时阻塞的是`getHitokoto(1111)`所在的线程
        JPrint("sleep over \(Thread.current)") // 子线程
        
//        let v1 = await value1
//        JPrint("v1 \(Thread.current)") // 子线程
//        let v2 = await value2
//        JPrint("v2 \(Thread.current)") // 子线程
//        return v1 + v2
        
        return await "value1 = " + value1 + ", " + "value2 = " + value2
    }
}

// MARK: - 🌰4.使用`withTaskGroup`或`withThrowingTaskGroup`并发执行多个异步函数
/// `Task Group`对比`async let`：
/// 1. 当在运行时才知道任务数量时；
/// 2. 需要为不同的子任务设置不同优先级；
/// 以上这两种情况下只能选择使用`Task Group`，在其他大部分情况下，两者可以混用甚至互相替代。
extension ViewController {
    @objc func btn4DidClick() {
        JPrint("btn4DidClick")
        
        JPrint("111 \(Thread.current)")
        
        Task {
            JPrint("222 \(Thread.current)")
            
            /// `withTaskGroup(of: XXX.self)`中的`XXX`表示`TaskGroup`中的`子Task`需要返回什么类型，Void就是不需要返回
            await withTaskGroup(of: Void.self) { group in
                
                JPrint("333 \(Thread.current)") // 调用函数的那个线程（主线程）
                
                group.addTask(priority: .low) {
                    JPrint("444 1 \(Thread.current)") // 子线程
                    await self.getHitokoto(444)
                    JPrint("444 2 \(Thread.current)") // `getHitokoto`内分配的子线程
                }
                
                group.addTask {
                    JPrint("555 1 \(Thread.current)") // 子线程
                    await self.getHitokoto(555)
                    JPrint("555 2 \(Thread.current)") // `getHitokoto`内分配的子线程
                }
                
                // 等上面的group全部执行完再继续
                JPrint("waitForAll \(Thread.current)")
                await group.waitForAll()
                
                JPrint("666 \(Thread.current)") // 回到调用函数的那个线程（主线程）
                
                group.addTask {
                    JPrint("777 1 \(Thread.current)") // 子线程
                    await self.getHitokoto(777)
                    JPrint("777 2 \(Thread.current)") // `getHitokoto`内分配的子线程
                }
                
            }
            
            // 会等上面的group全部执行完才到这里，到这里时会回到调用函数的那个线程（主线程）
            JPrint("888 \(Thread.current)")
            tv.backgroundColor = .randomColor
        }
    }
}

// MARK: - 🌰5.使用`for await`来访问`withTaskGroup`或`withThrowingTaskGroup`异步操作的结果
extension ViewController {
    @objc func btn5DidClick() {
        JPrint("btn5DidClick")
        
        JPrint("111 \(Thread.current)")
        
        Task {
            JPrint("222 \(Thread.current)")
            
            // 声明需要返回String类型
//            var result = ""
            let result = await withTaskGroup(of: String.self) { group -> String in
                
                JPrint("333 \(Thread.current)") // 调用函数的那个线程（主线程）
                
                // 定义一个变量用来捕获任务组的最终返回值，这个变量也可以在外部定义，然后在里面赋值
                var result = ""
                
                group.addTask {
                    let str = await self.getHitokoto(1111, delay: 5)
                    
                    ///【注意】：不建议在【子任务】内修改或访问某个共享变量
                    /// 因为这些代码有可能以并发方式同时运行，不加限制地从并发环境中访问是危险操作，可能造成崩溃。
                    /// 编译器可以检测到这里我们在一个明显的并发上下文中改变了某个共享状态，编译时会直接报错。
                    /// 如果是某个对象的属性，则可以在这里进行修改或访问，还是有可能造成崩溃，所以尽量不要在子任务内修改或访问某个共享变量！
//                    result += "\n" + str // 这是危险操作！
                    
                    return "1111：" + str
                }
                
                group.addTask {
                    let str = await self.getHitokoto(2222, delay: 1)
                    return "2222：" + str
                }
                
                ///【注意】：如果中途使用了`waitForAll()`，之后使用的`for await`是无法访问在此之前的所有task返回的结果
//                await group.waitForAll()
                
                group.addTask {
                    let str = await self.getHitokoto(3333, delay: 3)
                    return "3333：" + str
                }
                
                group.addTask {
                    let str = await self.getHitokoto(4444)
                    return "4444：" + str
                }
                
                JPrint("444 \(Thread.current)")
                
                /// `for await` 并不是指等全部任务都完成了才循环访问，而是循环对`TaskGroup内的全部Task`一起`await`了
                /// 也就是【不会按顺序】一个接一个地等待访问结果，而是全部任务都是并发执行，哪个任务先执行完就先访问谁的结果
                for await str in group {
                    JPrint("返回了啥", str, Thread.current) // 回到调用函数的那个线程（主线程）
                    result += "\n" + str // 应该是在这里捕获任务组中各个子任务的返回值，而不是子任务内
                }
                
                JPrint("555 \(Thread.current)")
                
                return result
                
                /**
                 * `TaskGroup`的双重保险：
                 *
                 * 1.如果我们没有调用`for await`，编译器会自动在这个 {} 的最后生成该代码：
                    `for await _ in group {}`
                 *
                 * 2.如果我们调用了`for await`，但中途`break`了，编译器会自动在这个 {} 的最后生成该代码：
                    `await group.waitForAll()`
                 *
                 * 确保了在这个 {} 退出前，让所有的子任务得以完成。
                 */
            }
            
            JPrint("总合集", result, Thread.current) // 回到调用函数的那个线程（主线程）
            tv.backgroundColor = .randomColor
            
            // 会等上面的group全部执行完才到这里，到这里时会回到调用函数的那个线程（主线程）
            JPrint("666 \(Thread.current)")
        }
    }
}

// MARK: - 🌰6.actor初体验
extension ViewController {
    
    enum HolderType {
        case unsafe
        case safe
        case actor
    }
    
    /// 不给予任何保护机制，可以随意访问资源内存，很容易造成内存错误 EXC_BAD_ACCESS
    class UnsafeHolder {
        private var results: [String] = []
        
        func getResults() -> [String] {
            results
        }
        
        func setResults(_ results: [String]) {
            self.results = results
        }

        func append(_ value: String) {
            results.append(value)
        }
    }
    
    /// 使用私有的`DispatchQueue`将资源保护起来，对资源的访问派发到同步队列中去执行，避免多个线程同时对资源进行访问
    class SafeHolder {
        private let queue = DispatchQueue(label: "Holder.queue")
        private var results: [String] = []
        
        func getResults() -> [String] {
            queue.sync {
                return self.results
            }
        }
        
        func setResults(_ results: [String]) {
            queue.sync {
                self.results = results
            }
        }

        func append(_ value: String) {
            queue.sync {
                self.results.append(value)
            }
        }
    }
    
    /// `actor`内部会提供一个隔离域：在`actor`内部对自身存储属性或其他方法的访问，可以不加任何限制，都会被自动隔离在【被封装的私有队列】里。
    /// 但是从外部对`actor`的成员进行访问时，编译器会要求切换到`actor` 的隔离域，以确保数据安全。
    /// 在这个要求发生时，当前执行的程序可能会发生暂停。编译器将自动把要跨隔离域的函数转换为【异步函数】，并要求我们使用`await`来进行调用。
    ///
    /// 个人理解：
    /// 也就是说，`actor`大概是类似`SafeHolder`的做法，内部有个被封装的私有同步队列用来进行对资源的访问（实际上不是，只是类似这种概念），
    /// 所有对资源的访问的函数/属性都得使用`await`调用，此时的函数会转换成异步函数，类似就是派发到私有同步队列中去执行的意思吧。
    actor ActorHolder {
        private var results: [String] = []
        
        func getResults() -> [String] {
            results
        }
        
        func setResults(_ results: [String]) {
            self.results = results
        }

        func append(_ value: String) {
            results.append(value)
        }
    }
    
    @objc func btn6DidClick() {
        JPrint("btn6DidClick")
        
        hType = .actor // 换.unsafe试一下，会内存错误（崩溃）
        maxCount = 50
        curCount = 0
        
        for _ in 0 ..< maxCount {
            Task {
                await test60()
            }
        }
        
        JPrint("done")
        
        /// 预期`results = ["0", "1", "2"]`，只有3个元素。
        /// 现在，在并发环境中访问资源，不论是基于`DispatchQueue`还是`actor`，也只能解决同时访问的造成的内存问题（崩溃），
        /// 依然可能会存在【多于】3个元素的情况。
        ///
        /// 对比由私有队列保护的“手动挡”的`class`，这个“自动档”的`actor`实现显然简洁得多
        ///
        /// 使用私有的`DispatchQueue`的缺点：
        /// 1. 维护成本高：凡是涉及`results` 的操作，都需要使用`queue.sync`包围起来，但是编译器并没有给我们任何保证。在某些时候忘了使用队列，编译器也不会进行任何提示，这种情况下内存依然存在危险。
        /// 2. 死锁：在一个`queue.sync`中调用另一个`queue.sync`的方法，会造成线程死锁。
    }
    
    func test60() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.test61()
            }
            group.addTask {
                await self.test62()
            }
        }
        
        curCount += 1
        if curCount == maxCount {
            
            let results: [String]
            switch hType {
            case .unsafe:
                results = uHolder.getResults()
            case .safe:
                results = sHolder.getResults()
            case .actor:
                results = await aHolder.getResults()
            }
            
            JPrint("全部搞定了", results, Thread.current)
            
            Asyncs.main {
                self.tv.backgroundColor = .randomColor
            }
        }
    }
    
    // 直接设置3个元素
    func test61() async {
        let delay = UInt64(arc4random_uniform(2))
        await Task.sleep(delay * NSEC_PER_SEC)
        
        switch hType {
        case .unsafe:
            uHolder.setResults(["0", "1", "2"])
        case .safe:
            sHolder.setResults(["0", "1", "2"])
        case .actor:
            await aHolder.setResults(["0", "1", "2"])
        }
    }
    
    // 先清空，再循环3次加入元素
    func test62() async {
        switch hType {
        case .unsafe:
            uHolder.setResults([])
        case .safe:
            sHolder.setResults([])
        case .actor:
            await aHolder.setResults([])
        }
        
        let delay = UInt64(arc4random_uniform(2))
        await Task.sleep(delay * NSEC_PER_SEC)
        
        for i in 0 ..< 3 {
            switch hType {
            case .unsafe:
                uHolder.append("\(i)")
            case .safe:
                sHolder.append("\(i)")
            case .actor:
                await aHolder.append("\(i)")
            }
        }
    }
}

// MARK: - 🌰7.`withUnsafeCurrentTask`初体验
extension ViewController {
    @objc func btn7DidClick() {
        JPrint("btn7DidClick")
        
//        withUnsafeCurrentTask { task in
//            JPrint("0", task ?? "null")
//        }
//
//        Task {
//            await test_withUnsafeCurrentTask()
//        }
        
        Task {
            print("========================= \(Thread.current)")
            await test70(0)
            print("========================= \(Thread.current)")
            await test70(1)
            print("========================= \(Thread.current)")
            await test70(2)
            print("========================= \(Thread.current)")
            await test70(3)
        }
        
        /**
         * 如果只是单纯想知道当前任务上下文是否被取消和其优先级，
         * 可以不使用`withUnsafeCurrentTask`，直接通过`Task`的静态函数获取：
         *  - `Task.isCancelled`
         *  - `Task.currentPriority`
         */
        
//        Task {
//            let t0 = Task {
//                let t1 = Task {
//                    JPrint("t1: \(Task.isCancelled)")
//                }
//
//                let t2 = Task {
//                    JPrint("t2: \(Task.isCancelled)")
//                }
//
//                t1.cancel()
//                JPrint("t0: \(Task.isCancelled)")
//            }
//
//            t0.cancel()
//            JPrint("t: \(Task.isCancelled)")
//        }
    }
    
    func test70(_ tag: Int) async {
        JPrint("\(tag) - test70 111", Thread.current)
        
        withUnsafeCurrentTask { task in
            if let task = task {
                if tag == 2 {
                    task.cancel() // 这个cancel应该只是单纯修改了isCancelled为true，需要自己判定这个isCancelled是否停止后面的操作
                }
                JPrint("\(tag) - test70 task is working,", "isCancelled:", task.isCancelled, Thread.current)
            } else {
                JPrint("\(tag) - test70 task is null", Thread.current)
            }
            
            JPrint("\(tag) - test70 222", Thread.current)
        }
        
        JPrint("\(tag) - test70 333", Thread.current)
    }
    
    func test_withUnsafeCurrentTask() async {
        JPrint("test_withUnsafeCurrentTask 1")
        
        /**
         * 使用`withUnsafeCurrentTask`获取到的任务（task）实际上是一个`UnsafeCurrentTask`值。
         * 和 Swift 中其他的`Unsafe`系 API 类似，Swift 仅保证它在`withUnsafeCurrentTask`的闭包中有效。你不能存储这个值，也不能在闭包之外调用或访问它的属性和方法，那会导致未定义的行为。
         */
        withUnsafeCurrentTask { task in
            JPrint("1", task ?? "null")
        }
        
        syncFunc()
        
        JPrint("test_withUnsafeCurrentTask 2")
    }
    
    func syncFunc() {
        JPrint("syncFunc 1")
        
        withUnsafeCurrentTask { task in
            JPrint("2", task ?? "null")
        }
        
        JPrint("syncFunc 2")
    }
}

// MARK: - 🌰8.`async let`再了解
extension ViewController {
    @objc func btn8DidClick() {
        JPrint("btn8DidClick")
        
        Task {
            await test8()
            tv.backgroundColor = .randomColor
        }
    }
    
    func test8() async {
        
        /**
         * `async let`赋值后，子任务会立即开始执行。
         */
        async let v0 = delay(2, return: 1)
        async let v1 = delay(4, return: 2)
        async let v2 = delay(1, return: 3)
        
        /**
         * 如果想要获取执行的结果 (也就是子任务的返回值)，可以对赋值的常量使用`await`等待它的完成。
         */
        
        /// 可以使用一个`await`同时获取3个结果：会暂停函数直到这3个任务执行完才继续
//        let result = await v0 + v1 + v2
        
        /// 分别使用`await`获取对应结果：会分别暂停函数去`等待对应任务执行完返回的结果`或者`直接去拿已经完成的结果`再继续
        let result0 = await v0
        JPrint("result0", result0, Thread.current)
        
        let result1 = await v1
        JPrint("result1", result1, Thread.current)
        
        let result2 = await v2
        JPrint("result2", result2, Thread.current)
        
        /**
         * 问题：分别对3个任务分别使用`await`获取结果，是不是会先等待上一个任务执行完，才开始下一个任务呢？例如这里总耗时是不是 2s + 4s + 1s = 7s ？
         * 答案：不是，这3个任务是一同开始以并发的方式进行的，分别耗时 2s、4s、1s，所以总耗时为3个任务中耗时最长的 4s。
         *
         * 解释：在`async let`创建子任务时，这个任务就开始执行了。
         * 例如`v2`是 1s 后完成，而`v1`是 4s 后完成，`v2`会比`v1`先完成，但是，使用`await`最终获取`v2`值的时刻，是严格排在获取`v1`值之后的，
         * 当`v2`任务完成后，它的结果将被【暂存】在它自身的续体栈上，等待执行上下文通过`await`切换到自己时，才会把结果返回。
         * 也就是说，通过`async let`绑定并开始执行后，`await v2`会在 1s 后完成，再经过 3s 时间，`await v1`完成，
         * 然后紧接着，`await v2`会把【3s 之前就已经完成的结果】立即返回给`result2`
         */
        
        let result = result0 + result1 + result2
        
        JPrint("总和", result, Thread.current)
    }
    
    func delay(_ delay: UInt64, return value: Int) async -> Int {
        JPrint("\(value) --- xixixi_begin", Thread.current)
        await Task.sleep(delay * NSEC_PER_SEC)
        JPrint("\(value) --- xixixi_end", Thread.current)
        return value
    }
    
    func test80() async {
//        async let v0 = delay(1, return: 1)
        
        /// `async let`的安全措施：如果整个函数都没有用`await`异步绑定，那么 Swift 并发会在被绑定的常量`v0`离开作用域时，隐式地将绑定的子任务取消掉，然后进行`await`。
        /// 编译器会隐式地在这个 {} 的最后生成这样的代码：
        /// 1. `v0.task.cancel()` --> `v0`绑定的任务被取消（伪代码，实际上绑定中并没有`task`这个属性）
        /// 2. `_ = await v0` --> 隐式`await`，满足结构化并发
    }
}

// MARK: - 🌰9.图片下载测试
extension ViewController {
    @objc func btn9DidClick() {
        JPrint("btn9DidClick")
        
        imgView.image = nil
        
        Task {
            JPrint("111 \(Thread.current)")
            
            let image1 = await loadImage(0) // 主线程
            imgView.backgroundColor = .randomColor
            imgView.image = image1
            JPrint("222 \(Thread.current)")
            
            await Task.sleep(1 * NSEC_PER_SEC)
            JPrint("333 \(Thread.current)")
            
            let image2 = await loadImage_watermark(1) // 主线程
            imgView.backgroundColor = .randomColor
            imgView.image = image2
            JPrint("444 \(Thread.current)")
            
//            await Task.sleep(1 * NSEC_PER_SEC)
//            JPrint("loadImage_wm 111", Thread.current) // 主线程
//            if let image = await loadImage(2) {
//                JPrint("loadImage_wm 222", Thread.current) // 主线程
//                let newImg = image.jp.watermark
//                JPrint("loadImage_wm 333", Thread.current) // 主线程
//                imgView.backgroundColor = .randomColor
//                imgView.image = newImg
//            }
        }
    }
    
    // 异步函数
    // 1.如果是在`另一个异步函数`或者`子Task`内调用该异步函数：执行完之后还是在被await分配到的线程中（子线程）
    // 2.如果是在`父Task`内调用该异步函数：执行完之后会回到调用该函数的那个线程（主线程）
    func loadImage_watermark(_ tag: Int) async -> UIImage? {
        JPrint("\(tag) - loadImage_wm 111", Thread.current) // 主线程
        if let image = await loadImage(tag) {
            JPrint("\(tag) - loadImage_wm 222", Thread.current) // 子线程
            let newImg = image.jp.watermark
            JPrint("\(tag) - loadImage_wm 333", Thread.current) // 子线程
            return newImg
        } else {
            return nil
        }
    }
    
    func loadImage(_ tag: Int) async -> UIImage? {
        JPrint("\(tag) - loadImage_start", Thread.current)
        do {
            let url = URL(string: "https://picsum.photos/500/500?random=\(arc4random_uniform(5000))")
            let rsp = try await URLSession.shared.download(from: url!, delegate: nil)
            JPrint("\(tag) - loadImage_success", URL(string: rsp.0.path)!.lastPathComponent, Thread.current)
            return UIImage(contentsOfFile: rsp.0.path)
        } catch {
            JPrint("\(tag) - loadImage_failed", Thread.current)
            return nil
        }
    }
}
