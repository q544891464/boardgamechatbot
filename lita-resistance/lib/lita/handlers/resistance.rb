module Lita
  module Handlers
    class Resistance < Handler

      route(/resistance help/, :help, command: true, help: {'resistance help' => '显示游戏帮助'})

      route(/resistance [NCBSAFD]+ .+/, :play, command: true, help: {'resistance N|[CBSAFD] [users]' => '将间谍/抵抗者分配给你@的玩家'})

      route(/mission S|F/, :mission, command: true, help: {'mission S(Success)|F(Fail)' => '执行任务（成功或失败）.'})

      route(/assign .+/, :assign, command: true, help: {'assign [users]' => '指派执行任务的玩家'})

      route(/Yes/, :agree, command: true, help: {'Yes' => '同意任务分配'})

      route(/No/, :disagree, command: true, help: {'No' => '不同意任务分配'})

      route(/test .+/, :test, command: true, help: {'test' => 'for test'})
      def help (response)
        response.reply(render_template("help"))
      end

      # Remove any "@" from usernames
      def normalize_input! (all_users)
        all_users.map! do |username|
          if username[0] == '@'
            username[1, username.length-1]
          else
            username
          end
        end
      end

      def verify_characters (characters)
        if characters != characters.uniq
          raise 'You cannot have more than one of the same character.'
        end

        if characters.include?('N') && characters.length > 1
          raise 'You cannot include special characters with N.'
        end

        # Num of Special Characters on spies doesn't exceed num of spies
        if !characters.include?('N') && (characters - ['C', 'B']).length > @num_spies
          raise 'You cannot have more special characters on spies than the number of spies.'
        end
      end

      def validate_input (response)
        input_args = response.args.uniq
        @characters = input_args[0].split(//)
        all_users = input_args[1, input_args.length - 1] # User mention_names

        if all_users.length < 5
          raise 'You need at least 5 players for Resistance.'
        elsif all_users.length > 10
          raise 'You cannot play a game of Resistance with more than 10 players.'
        end

        @num_spies = (all_users.length + 2) / 3

        verify_characters(@characters)

        normalize_input!(all_users)

        # Ensure all people are users.
        unknown_users = []
        all_users.each do |username|
          user = Lita::User.find_by_mention_name(username)
          unknown_users.push(username) unless user
        end

        if unknown_users.any?
          raise "The following are not users: @#{unknown_users.join(' @')}"
        end

        all_users
      end

      def assign_spies (spies)
        spy_specials = {}
        if @characters.include?('D')
          spy_specials[:deep_cover] = spies.sample
        end

        if @characters.include?('F')
          spy_specials[:false_commander] = (spies - spy_specials.values).sample
        end

        if @characters.include?('B')
          spy_specials[:blind_spy] = (spies - spy_specials.values).sample
        end

        if @characters.include?('A')
          spy_specials[:assassin] = (spies - spy_specials.values).sample
        end

        spies.each do |member|
          user = Lita::User.find_by_mention_name(member)
          other_spies = spies.dup - [spy_specials[:blind_spy], member] # Don't mention Blind Spy or self
          if member == spy_specials[:blind_spy]
            record_identity(user,"blind_spy")
          elsif member == spy_specials[:deep_cover]
            record_identity(user,"deep_cover")
          elsif member == spy_specials[:false_commander]
            record_identity(user,"false_commander")
          elsif member == spy_specials[:assassin]
            record_identity(user,"assassin")
          else
            record_identity(user,"spy")
          end
          robot.send_message(Source.new(user: user),
                             render_template('spy', { spy_specials: spy_specials,
                                                      other_spies: other_spies,
                                                      member: member,
                                                      starter: @starter,
                                                      game_id: @game_id }))
        end
        spy_specials
      end

      def assign_resistance (resistance, spies, spy_specials)
        if @characters.include?('C')
          commander = resistance.sample
          commander_visible = spies - [spy_specials[:deep_cover]]
        end

        if @characters.include?('B')
          bodyguard = (resistance - [commander]).sample
          bodyguard_visible = [commander, spy_specials[:false_commander]].shuffle.compact
        end

        resistance.each do |member|
          user = Lita::User.find_by_mention_name(member)
          if member == commander
            record_identity(user,"commander")
          elsif member == bodyguard
            record_identity(user,"bodyguard")
          else
            record_identity(user,"resistance")
          end
          robot.send_message(Source.new(user: user),
                             render_template("resistance", { commander: commander,
                                                             bodyguard: bodyguard,
                                                             bodyguard_visible: bodyguard_visible,
                                                             commander_visible: commander_visible,
                                                             member: member,
                                                             starter: @starter,
                                                             game_id: @game_id,
                                                             spy_specials: spy_specials }))
        end
      end
      def play(response)
        #set_game_status(0)

        begin
          all_users = validate_input(response)
        rescue StandardError => error
          response.reply(error.to_s) and return
        end
        game_initialize(all_users)

        @game_id = rand(999999)
        @starter = response.user.mention_name # Person who started the game
        # Form teams
        spies = all_users.sample(@num_spies)
        resistance = all_users - spies
        #Lita.redis.set("Num","666")
        spy_specials = assign_spies(spies)
        assign_resistance(resistance, spies, spy_specials)
        numofresistance = redis.get("Num")
        leader = all_users.sample # Randomly pick a leader for the first round

        identity_of_leader = get_identity_of(leader)
        response.reply("身份已经分配完毕! 本场游戏的id为 ##{@game_id}. @#{leader} 将会成为第一回合的队长.")
        #response.reply("leader的身份是:#{identity_of_leader}")
        game_continue
        robot.send_message(Source.new(room: get_room),"游戏阶段:第#{get_game_status}回合，本回合需要#{mission_total_progress(get_game_status)}人执行任务，请队长选出合适人选，玩家们讨论并投票 指令：assign [users]")
      end

      #分配人员阶段
      def assign (response)

        if get_game_status == "0" #执行任务者执行任务
          response.reply("游戏还未开始")
          raise("游戏还未开始")
        end

        user = response.user.mention_name

        if get_leader != user
          response.reply("你不是队长，不能指派任务：")
          raise("你不是队长，不能指派任务：")
        end

        input_args = response.args.uniq
        assign_users = input_args[0, input_args.length] # User mention_names

        #response.reply("你输入的用户为：#{assign_users}")

        if assign_users.length != Integer(mission_total_progress(get_game_status))
          response.reply("你需要#{mission_total_progress(get_game_status)}个人执行任务")
          raise "你需要#{mission_total_progress(get_game_status)}个人执行任务"
        end
        normalize_input!(assign_users)

        # Ensure all people are users.
        unknown_users = []
        assign_users.each do |username|
          user = Lita::User.find_by_mention_name(username)
          unknown_users.push(username) unless user
        end
        if unknown_users.any?
          response.reply("他们不是用户: @#{unknown_users.join(' @')}")
          raise "他们不是用户: @#{unknown_users.join(' @')}"
        end

        assign_users.each do |member|
          record_assign(member,1) #设置他们可以执行任务
        end

        broadcast("指派执行任务的玩家为@#{assign_users.join('@')}")

        set_agree_status(1) #开始投票

        broadcast("请所有玩家为该任务分配投票 同意：Yes 不同意：No")

      end


      #redis值：
      # 初始化时记录玩家人数 num_of_users 记录所有玩家名字（list）
      # username_agree_available 表示该用户是否有权利同意
      # 每位玩家输入 agree 或 disagree 后权利变为0 计数total_count+1 count
      # total_count == 玩家人数 时结束计数
      # count 大于 total_count 一半时进入执行任务阶段
      # 设置agree_status表示是否再投票阶段 mission阶段里加上该验证
      # 否则重新执行 设置所有玩家available值为1 设置所有玩家 record_assign为0 即所有人都没有被指派

      def agree (response)
        if get_agree_status != 1
          response.reply("你还不能投票（还未到投票同意阶段）")
          raise("")
        end
        #todo 最后还需做投票权利的限制 目前一个人可以投多次票
        user = response.user.mention_name
        set_user_agreeable(user,0) #失去投票机会
        agree_count #同意票+1
        #response.reply("agree_count")
        total_count #总票数+1
        #response.reply("total_count")
        broadcast("#{user}同意该任务分配")
        agree_stage
      end

      def disagree (response)
        if get_agree_status != 1
          response.reply("你还不能投票（还未到投票同意阶段）")
          raise("")
        end
        #todo 最后还需做投票权利的限制 目前一个人可以投多次票
        user = response.user.mention_name
        set_user_agreeable(user,0) #失去投票机会
        total_count #总票数+1
        broadcast("#{user}不同意该任务分配")
        agree_stage
      end

      #投票同意阶段
      def agree_stage
        if get_total_count == get_num_of_users
          if get_agree_count > get_total_count/2 #如果半数以上同意
            set_agree_status(0) #不可以再投票/投票结束
            get_all_users.each do|member| #每个人恢复投票权力
              set_user_agreeable(member,1)
            end
            set_agree_count(0)  #票数清零
            set_total_count(0)  #票数清零
            broadcast("该任务分配已被半数以上同意，请任务执行者执行任务。指令：mission S|F(任务成功|任务失败)")
          else
            #如果没到半数以上同意
            set_agree_status(0) #不可以再投票/投票结束
            #每个人恢复投票权力
            # 所有人都取消指派
            get_all_users.each do|member|
              set_user_agreeable(member,1)
              record_assign(member,0)
            end
            set_agree_count(0)  #票数清零
            set_total_count(0)  #票数清零
            broadcast("该任务分配未被半数以上同意，请队长重新指派任务")
          end
        end
      end

      #执行任务阶段
      def mission (response)
        if get_game_status == "0" #执行任务者执行任务
          response.reply("游戏还未开始")
        else
          user = response.user.mention_name
          unless is_assign(user) #如果用户没被分配任务
            response.reply("你不能执行任务")
            raise("你不能执行任务")
          end

          if get_agree_status == 1  #如果投票仍在进行中
            response.reply("投票未完成，你不能执行任务")
            raise("投票未完成，你不能执行任务")
          end
          input_args = response.args.uniq
          mission_character = input_args[0]
          mission_result = mission_character[0] #取第一个字符为结果

          #如果投票任务成功 投票进度+1 任务完成进度+1
          #如果投票任务失败 投票进度+1 任务完成进度不变
          if mission_result == "S"
            mission_success
            vote_success
          else
            vote_success
          end

          response.reply("投票成功")
          #test
          response.reply("当前任务进度"+get_mission_progress)
          response.reply("当前投票进度"+get_vote_progress)

          voter_name = response.user.mention_name
          #todo 测试需要将这行代码注释 目的是一个人可以执行多次任务
          #record_assign(voter_name,0)

          broadcast("@#{voter_name}已投票，已投票/任务总进度:"+get_vote_progress+"/"+mission_total_progress(get_game_status))
          #如果所有投票的人都投成功 则任务成功
          #有人没投成功 则任务失败
          if is_vote_complete
            if is_mission_complete
              robot.send_message(Source.new(room: get_room),"投票完成，第#{get_game_status}回合任务成功！")
              mission_completed
            else
              robot.send_message(Source.new(room: get_room),"投票完成，第#{get_game_status}回合任务失败！")
            end
            broadcast("本轮执行任务情况为：成功/总数  #{get_mission_progress}/#{mission_total_progress(get_game_status)}")

            game_continue

            if is_game_over
              if get_winner == "resistance"
                broadcast("成功完成了三次任务,抵抗者取得了胜利")
              elsif get_winner == "spy"
                broadcast("抵抗者们没能完成三次任务，间谍们取得了胜利")
              end
              set_game_status(0)
            else
              broadcast("进入下一回合,当前为第#{get_game_status}回合,已完成任务情况为#{get_completed_mission}/3")
              broadcast("游戏阶段:第#{get_game_status}回合，本回合需要#{mission_total_progress(get_game_status)}人执行任务，请队长选出合适人选，玩家们讨论并投票 指令：assign [users]")
            end
          end
        end
      end

      #测试用
      def test (response)
        input = response.args.uniq[0]
        if input == "changeleader"
          change_leader
          response.reply("队长已改变，现任队长为#{get_leader}")
        end
        #set_mission_progress(0)
        #set_vote_progress(0)
        #set_game_status(1)
        #set_completed_mission(0)
        #record_assign("weifanchen1997",0)
        #set_leader("weifanchen1997")

        #room_id = response.room.id
        #response.reply("这个房间的id是#{room_id}")
        #redis.set("room_id",room_id)
        #this_room = Lita::Room.find_by_id(room_id)
        #response.reply("这个房间的name是#{this_room.name}")
        #broadcast("hello world")

      end


      def game_initialize(all_users)
        set_mission_progress(0) #设置执行任务阶段任务成功进度
        set_vote_progress(0)  #设置执行任务阶段投票进度
        set_completed_mission(0)  #设置已完成任务数量
        set_game_status(0)  #设置游戏状态为0
        set_num_of_users(all_users.length)  #设置玩家人数
        set_agree_count(0)  #设置同意投票阶段同意票数
        set_total_count(0)  #设置同意投票阶段总票数
        set_agree_status(0) #设置同意投票阶段状态
        all_users.each do |member|
          record_assign(member,0) #设置所有人不能执行任务
          redis.lpush("all_users",member) #存所有人的名字
          set_user_agreeable(member,1) #所有人可以投票
          #broadcast("#{member}储存成功")
        end
      end



      #在redis中按id记录身份
      def record_identity(user, identity)
        user_id = user.id
        redis.set(user_id,identity)
      end

      #按用户名获取身份
      def get_identity_of(user_name)
        user = Lita::User.find_by_mention_name(user_name)
        user_id = user.id
        redis.get(user_id)
      end

      #设置游戏状态
      # 0：游戏未开始
      # 1：发牌结束 可以投票 第一回合
      # 2：第二回合
      # 3：第三回合
      # 4：第四回合
      # 5：第五回合
      # 99：预留
      def set_game_status(status)
        redis.set("game_status",status)
      end

      #获取游戏状态
      def get_game_status
        redis.get("game_status")
      end

      #游戏进入下一阶段 game_status +1
      def game_continue
        game_status = Integer(get_game_status)
        set_vote_progress(0)  #重置任务执行情况
        set_mission_progress(0) #重置任务执行成功情况
        redis.set("game_status",game_status+1)
      end

      #设置任务进度
      def set_mission_progress(progress)
        redis.set("mission_progress",progress)
      end

      #获取任务进度
      def get_mission_progress
        redis.get("mission_progress")
      end

      # 获取当前任务需要的总进度
      # 五个人游戏的情况下 每回合任务需要的进度分别为：2-3-2-3-3
      # 更多人游戏的情况可以之后再做
      def mission_total_progress(game_status)
        if game_status == "1"
          "2"
        elsif game_status == "2"
          "3"
        elsif game_status == "3"
          "2"
        elsif game_status == "4"
          "3"
        elsif game_status == "5"
          "3"
        end
      end

      #投票任务成功 任务进度+1
      def mission_success
        mission_progress = Integer(get_mission_progress)
        mission_progress += 1
        set_mission_progress(mission_progress)
      end

      #设置已完成的任务数量
      def set_completed_mission(completed_mission)
        redis.set("completed_mission",completed_mission)
      end

      #获取已完成的任务数量
      def get_completed_mission
        redis.get("completed_mission")
      end

      #任务成功完成 已完成任务+1
      def mission_completed
        completed_mission = Integer(get_completed_mission)
        completed_mission += 1
        set_completed_mission(completed_mission)
      end

      #设置投票进度 执行任务阶段
      def set_vote_progress(vote_progress)
        redis.set("vote_progress",vote_progress)
      end

      #获取投票进程 执行任务阶段
      def get_vote_progress
        redis.get("vote_progress")
      end

      #投票成功 投票进度+1 执行任务阶段
      def vote_success
        vote_progress = Integer(get_vote_progress)
        vote_progress += 1
        set_vote_progress(vote_progress)
      end

      #投票是否完成
      def is_vote_complete
        if get_vote_progress == mission_total_progress(get_game_status)
          true
        else
          false
        end
      end


      # 任务是否完成
      # 检查当前完成任务人数是否达到任务所需进度
      def is_mission_complete
        if get_mission_progress == mission_total_progress(get_game_status)
          #set_mission_progress(0)
          true
        else
          #set_mission_progress(0)
          false
        end
      end

      #游戏是否结束
      def is_game_over
        completed_mission = Integer(get_completed_mission)
        game_status = Integer(get_game_status)
        if completed_mission >= 3 or game_status - completed_mission - 1 >= 3 or game_status > 5
          true
        else
          false
        end
      end

      #游戏胜者
      # 已完成3任务抵抗者胜利
      # 未完成3任务间谍方胜利
      def get_winner
        completed_mission = Integer(get_completed_mission)
        if completed_mission >= 3
          "resistance"
        else
          "spy"
        end
      end

      #获取当前游戏房间
      def get_room
        room_id = redis.get("room_id")
        Lita::Room.find_by_id(room_id)
      end

      #广播 - 在游戏房间广播
      def broadcast(string)
        robot.send_message(Source.new(room: get_room),string)
      end

      #记录玩家是否执行任务 1为可以 0为不可以
      def record_assign(user,status)
        redis.set(user+"_assign_status",status)
      end

      #判断玩家是否可以执行任务
      def is_assign(user)
        status = redis.get(user+"_assign_status")
        if status == "1"
          true
        else
          false
        end
      end

      #设置队长
      def set_leader(leader)
        redis.set("leader",leader)
      end

      #获取队长
      def get_leader
        redis.get("leader")
      end

      #设置玩家人数
      def set_num_of_users(num_of_users)
        redis.set("num_of_users",num_of_users)
      end

      #获取玩家人数
      def get_num_of_users
        Integer(redis.get("num_of_users"))
      end

      #获取玩家列表
      def get_all_users
        redis.lrange("all_users",0,get_num_of_users-1)
      end

      #设置玩家是否可以投票同意 1为可以 0为不可以
      def set_user_agreeable(user,agreeable)
        redis.set(user+"_agreeable",agreeable)
      end

      #获取玩家是否可以投票同意
      def get_user_agreeable(user)
        Integer(redis.get(user+"_agreeable"))
      end

      #设置同意数 同意投票阶段
      def set_agree_count(count)
        redis.set("agree_count",count)
      end

      #获得同意数 同意投票阶段
      def get_agree_count
        Integer(redis.get("agree_count"))
      end

      #同意数+1 同意投票阶段
      def agree_count
        count = get_agree_count
        count += 1
        set_agree_count(count)
      end

      #设置同意投票阶段总投票数
      def set_total_count(count)
        redis.set("total_count",count)
      end

      #获得同意投票阶段总投票数
      def get_total_count
        Integer(redis.get("total_count"))
      end

      #同意阶段总投票数+1
      def total_count
        total_agree_count = get_total_count
        #response.reply("total_agree_count = get_total_count")
        total_agree_count += 1
        #response.reply("total_agree_count += 1")
        set_total_count(total_agree_count)

      end

      #设置同意投票阶段状态
      # 0：不可以投票
      # 1：投票进行中
      def set_agree_status(status)
        redis.set("agree_status",status)
      end

      #获取同意投票阶段状态
      def get_agree_status
        Integer(redis.get("agree_status"))
      end

      def change_leader
        leader = get_all_users.sample
        set_leader(leader)
      end


      Lita.register_handler(self)
    end
  end
end
