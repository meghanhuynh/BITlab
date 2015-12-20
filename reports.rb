require_relative 'report_builder'

def daily_report(client, user_id, hours = 0)
  report = UserReport.new(client, user_id) do |r|
    if( not r.make_graphs()) ###This line of code takes awhile to run(4seconds ish)
      return false #This report can not be made because the user does not have enough data
    end

    r.br
    r.br
    img_dim = [541, 148]
    r.img(file_loc = "bitlab_wide.jpg", img_size = img_dim)

    r.br
    r.br
    r.center "Computer Security Report", :style=> "font: bold 60px arial,serif ";
    # , :style=>"color:#8C001A ";

    d = Time.now.strftime("%B %-d, %Y")
    r.center "Report created: #{d}", :style=> "font: bold 30px arial,serif ";
    #:style=> "color:#909090 ";

    begin
      participation_start = r.q("SELECT DATE(MIN(`date.started`)) FROM pre_survey WHERE user_id = #{user_id}").strftime("%B %-d, %Y")
      participation_end = r.q("SELECT DATE(MAX(`date.ended`)) FROM post_survey WHERE user_id = #{user_id}").strftime("%B %-d, %Y")

      if(participation_start.nil? or participation_end.nil?)
        raise "user does not have start and end survey so put default response of Spring 2015"
      end

      r.h3 {r.center "Participated from: #{participation_start} to: #{participation_end}", :style=> "font: bold 20px arial,serif ";}

    rescue
      r.h3 {r.center "Participated Spring 2015", :style=> "font: bold 20px arial,serif ";}
    end


    #these users had to use fieldstudyproduction ot get the dates of participation but for windows portion have to use dr3.
    #after windows portion they will switch back to browser
    if(r.get_edge_type() == "windows_in_dr3")
      r.change_db_dr3()
    end

    r.br
    r.br

    r.hr

    r.br
    r.br

    ################################START OF WINDOWS SECTION############################################################
    if(not r.get_edge_type() == "browser_only") #don't do any of this because we have no windows data. THIS BLOCK DOES NOT PREVENT FIREWALL SETTINGS
       r.div "Basic Facts", :style=> "font: bold 25px arial,serif ";
       r.div "Your Computer", :style=> "font: bold 20px arial,serif ";
       r.div "Manufacturer: #{r.q("select manufacturer from win_computer_hardware where user_id=#{user_id} limit 1")}", :style=> "font: 20px arial,serif ";
       r.div "Model: #{r.q("select model from win_computer_hardware where user_id=#{user_id} limit 1")}" , :style=> "font: 20px arial,serif ";

       os = r.q("select version from win_operating_system where user_id =#{user_id} limit 1")
       if os.include? "6.1"
         r.div "Operating System: Windows 7", :style=> "font: 20px arial,serif ";
       elsif os.include? "6.2"
         r.div "Operating System: Windows 8", :style=> "font: 20px arial,serif ";
       else
         r.div "Operating System: Windows 8.1", :style=> "font: 20px arial,serif ";
       end

       r.br
       if (not r.get_skip_usage_fig()) #boolean value that tells us if we should skip the usage figure
         usage_fig_loc = r.get_usage_figure() #this block of code adds the usage figure to the report
         img_dim = [400, 350]
         fig_caption = "Graph of user's computer time running vs. average usage of all users' computer time running"
         r.img(file_loc = usage_fig_loc, img_size = img_dim, img_caption = fig_caption)
       else
         puts "skipping usage figure for user_id: #{user_id}"
       end

       r.br
       r.div "User Account Control", :style=> "font: bold 25px arial,serif ";
       r.br
       r.div "When a new piece of software asks for the right to make changes to your computer, such as when
       installing software, Windows can show you a warning and ask if this piece of software should be allowed
       to make changes. This dialog is called a User Account Control (UAC) dialog. By default Windows
       displays the UAC dialog by turning the screen black and showing a dialog window asking for your
       approval. It is possible for either you or software acting on your behalf to turn off these warnings.
       You can nd these settings by going to the Control Panel, selecting the System and Security
       category, and then clicking on Change User Account Control settings Action Center, or
       search for Change User Account Control settings in the search bar.
       It is recommended that you keep these warnings on. When they are off, any piece of software can
       make changes to important settings on your computer without your knowledge.", :style=> "font: 18px arial,serif ";
       r.br
       warnings = r.q("select if(consent_prompt_behavior_admin=
                         'ElevateWithoutPrompting','No','Yes') as admin,
                          if(consent_prompt_behavior_user=
                          'AutoDenyElevationRequests','Deny all',
                          if(consent_prompt_behavior_user='Undefined','No','Yes')
                          ) as user
                          from win_security_settings where user_id
                          =#{user_id} order by id desc limit 1")
       if (warnings == "Yes") #warnings[0] == "Yes" and warnings[1] == "Yes")
         r.div "The User Account Control warnings are TURNED ON for your computer", :style=> "font: 20px arial,serif ";
       elsif (warnings[0] == "Yes" or warnings[1] == "Yes")
         r.div "The User Account Control warnings are SOMETIMES ON for your computer", :style=> "font: 20px arial,serif ";
       else
         r.div "The User Account Control warnings are TURNED OFF for your computer", :style=> "font: 20px arial,serif ";
       end

       r.br

        r.div "Windows Updates", :style=> "font: bold 25px arial,serif ";
        r.br
        r.div "Microsoft, the company that produces Windows, occasionally nds issues with their software and releases
        updates to x the issues. The recommended and default setting on Windows is to automatically check
        for recommended and security updates and then install them. Microsoft also releases optional
        updates, and these are not installed unless you change your settings or manually install them.
        You can nd these settings by going to the Control Panel, selecting the System and Security category,
        and clicking on Turn automatic updating on or off under Windows Update, or by searching Turn
        automatic updating on or off in the search bar.", :style=> "font: 18px arial,serif ";

        res = r.q("select update_notification_level,
                             update_schedule_install_day,
                             update_schedule_install_time,
        update_include_recommended, update_non_admin_elevated,
        update_featured_enabled from win_security_settings where
        user_id=#{user_id} limit 1")

        r.br

        #TODO check for days
            if(res == "NotConfigured" or res == "Disabled")
              r.div "You DO NOT have the recommended update settings.", :style=> "font: 20px arial,serif ";


              r.div  "Your computer:", :style=> "font: 20px arial,serif ";
              r.div  "Auto checks for updates - No", :style=> "font: 20px arial,serif ";
            else
              r.div  "You HAVE the recommended update settings.", :style=> "font: 20px arial,serif ";

              r.div  "Your computer: ", :style=> "font: 20px arial,serif ";
              r.div  "Auto-Checks for updates - Every day", :style=> "font: 20px arial,serif ";
              what_day = "on #{res[1]}"
              if(res[1] == "EveryDay")
                what_day = "Every day"
              end


            if(res[0] == "NotifyBeforeDownload")
              r.puts "Auto checks for updates & Yes - #{what_day} \\\\"
              r.puts "Auto downloads updates & No \\\\"
              r.puts "Auto installs updates & No \\\\"
            elsif(res[0] == "NotifyBeforeInstallation")
              r.puts "Auto checks for updates & Yes - #{what_day} \\\\"
              r.puts "Auto downloads updates & Yes \\\\"
              r.puts "Auto installs updates & No \\\\"
            elsif(res[0] == "ScheduledInstallation")
              r.puts "Auto checks for updates & Yes - #{what_day} \\\\"
              r.puts "Auto downloads updates & Yes \\\\"
              r.puts "Auto installs updates & Yes \\\\"
            end
          end

        r.br

      begin
        windows_updates = r.get_updates()
        fig_caption = "Number of windows updates downloaded on each date"
        img_dim = [450, 350]
        r.img(file_loc = windows_updates, img_size = img_dim, img_caption = fig_caption)
      rescue
        puts "skipping updates figure for this user because they do not have enough snapshots where updates took place"
      end



      r.div "Software Updates", :style=> "font: bold 25px arial,serif ";
      r.br
      r.div "Using out-of-date versions of software may pose serious security risks to your computer. Your risk of
      getting infected with viruses or malware is less if all of your software is up to date. Internet Browsers,
      Java, and Adobe Reader are most likely to be out-of-date.", :style=> "font: 18px arial,serif ";
      r.div "For your computer:", :style=> "font: 18px arial,serif ";

      r.br
      r.div "Name Updated", :style=> "font: bold  16px verdana";
      chr = r.q("SELECT date(min(local_time)) as tim,display_name,
                      version FROM win_installed_applications where
      user_id = #{user_id} and display_name like 'Google Chrome'
      group by display_name order by id desc limit 1")

        if chr != "35.0.1916.153"
          r.div "Google Chrome - No ", :style=> "font: 16px verdana";
        else
          r.div "Google Chrome - Yes ", :style=> "font:  16px verdana";
        end

      f = r.q("SELECT date(min(local_time)) as tim,display_name,
                      version FROM win_installed_applications where
      user_id = #{user_id} and display_name like '%Firefox%'
      group by display_name order by id desc limit 1")

        if f != "30.0"
          r.div "Mozilla Firefox - No", :style=> "font: 16px verdana";
        else
          r.div "Mozilla Firefox - Yes", :style=> "font:   16px verdana";
        end

      have_java = false
      j = r.q("SELECT date(min(local_time)) as tim,
                      display_name,version FROM win_installed_applications
                      where user_id = #{user_id} and display_name like
                      '%Java 7 Update%' group by display_name order by
                      id desc limit 1")


        have_java = true
        if j != "Java 7 Update 60" or j != "Java 7 Update 55"
          r.div "Java* - No", :style=> "font:  16px verdana";
        else
          r.div "Java* - Yes", :style=> "font: 16px verdana";
        end

      a= r.q("SELECT date(min(local_time)) as tim,
      substring_index(display_name, ' ', 3) as display_name,
      version FROM win_installed_applications where user_id =
      #{user_id} and display_name like '%Adobe Reader%'
      group by display_name order by id desc limit 1")

      if a != "11.0.07" or a != "10.1.10" or a != "9.5.5" or a != "8.3.1"
        r.div "Adobe Reader - No", :style=> "font: 16px verdana";
      else
        r.div "Adobe Reader - Yes", :style=> "font: 16px verdana";
      end

      r.br
      r.div "*Java is a program that is not normally used by computer
      users directly. It is a program that other programs need to function.", :style=> "font: 18px arial,serif ";

      r.br
      r.div "Firewalls", :style=> "font: bold 25px arial,serif ";
      r.br
      r.div "A rewall is a program that prevents other computers on the internet from interacting with your computer
      unless you interact with them rst. You should have a rewall installed on your computer and have it
      on at all times. Windows comes pre-installed with a rewall; however, you can also install your own.
      You can nd these settings by going to the Control Panel, selecting the System and Security category
      and then clicking on Check rewall status under Windows Firewall or by searching Check rewall
      status in the search bar. The following are the rewall(s) installed on your computer:", :style=> "font: 18px arial,serif ";

      r.br
      res = r.div {r.query("select
        case when id > 0 then 'Windows Firewall'
        end Name,
        case when (domain_enabled = 'True' and private_enabled = 'True' and public_enabled = 'True') = 1
          then 'Yes'
          else 'No'
        end Running,
        case when (domain_enabled = 'True' or private_enabled = 'True' or public_enabled = 'True') = 1
          then 'Yes'
          else 'No'
        end Updated
        from win_firewall,
      (select max(snapshot) as smax from win_firewall where user_id=#{user_id}) as sub
      where user_id=#{user_id} and sub.smax = snapshot")}

      r.br
      r.div "Antivirus", :style=> "font: bold 25px arial,serif ";
      r.br
      r.div "Antivirus software protects your computer from viruses by actively scanning your computer for potentially
      infected software. You should install and turn on automatic updates so that you can have the strongest
      protection from these security threats.If you have multiple antivirus programs installed, only one should be running.
      If you have multiple antivirus programs running at the same time, they can attack each other and put your computer's
      security at risk. The following are the antivirus program(s) installed on your computer:", :style=> "font: 18px arial,serif ";

      r.br

      res = r.  div {r.query("select name as Name,
                    case when running_raw = '10' then 'Yes'
                         when running_raw = '01' then 'No'
                    end Running,
                    case when up_to_date_raw = '00' then 'Yes' else 'No'
                    end Updated
                     from win_security_products,
                     (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
                     as sub
                     where user_id=#{user_id}
                     and type = 'AntiVirusProduct' and sub.smax = snapshot")}
      r.div (res[0])

      count = r.q("select count(name) from win_security_products,
              (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
              as sub
              where user_id=#{user_id}
              and type = 'AntiVirusProduct' and sub.smax = snapshot")

      r.br

      if count == '0'
        r.div "Currently, you DO NOT have any anti-spyware software
        installed on your computer. We recommend that you consider
        installing one of the following free anti-spyware programs that have
        received high ratings to protect your computer: Ad-Aware Free Antivirus, Malwarebytes Anti-Malware, Emsisoft Anti-Malware Free", :style=> "font: 18px arial,serif ";

      elsif count == '1'
        r.div "You have multiple antivirus programs running at the same time. This could potentially put your computer at risk", :style=> "font: 20px arial,serif ";
      else
        r.div "Your antivirus is in a GOOD state", :style=> "font: 20px arial,serif ";
      end

      r.br
      r.div "Anti-spyware", :style=> "font: bold 25px arial,serif ";
      r.br
      r.div "Anti-spyware software looks for potentially malicious software on your computer that might steal per-
      sonal information like passwords or bank credentials. Many antivirus programs come with anti-spyware
      included.If you have multiple anti-spyware programs installed, only one should be running. If you have multiple
      anti-spyware programs running at the same time, they can attack each other and put your computer's
      security at risk.
      The following are the anti-spyware program(s) installed on your computer:", :style=> "font: 18px arial,serif ";
      r.br
      res = r.div {r.query("select name as Name,
                    case when running_raw = '10' then 'Yes'
                         when running_raw = '01' then 'No'
                    end Running,
                    case when up_to_date_raw = '00' then 'Yes' else 'No'
                    end Updated
                     from win_security_products,
                     (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
                     as sub
                     where user_id=#{user_id}
                     and type = 'AntiSpywareProduct' and sub.smax = snapshot")}
      r.div (res[0])
      count = r.q("select count(name) from win_security_products,
              (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
              as sub
              where user_id=#{user_id}
              and type = 'AntiSpywareProduct' and sub.smax = snapshot")
      r.br
      if count == '0'
        r.div "Currently, you DO NOT have any anti-spyware software
        installed on your computer. We recommend that you consider
        installing one of the following free anti-spyware programs that have
        received high ratings to protect your computer: Ad-Aware Free Antivirus, Malwarebytes Anti-Malware, Emsisoft Anti-Malware Free", :style=> "font: 18px arial,serif ";

      elsif count == '1'
        r.div "You have multiple antivirus programs running at the same time. This could potentially put your computer at risk", :style=> "font: 20px arial,serif ";
      else
        r.div "Your antivirus is in a GOOD state", :style=> "font: 20px arial,serif ";
      end

      r.br
      r.div "Wireless Networks", :style=> "font: bold 25px arial,serif ";
      r.br
      r.div "A wireless network is a network you connect to when you want to access the internet without using an
      actual wire. Below is a table of wireless networks that your computer has connected to. An automatic
      connection means that your computer connected to this wireless network without asking you at least
      once. Otherwise, the connection is manual, and your computer always asks you before connecting to
      this network. A password protected network is one where you had to enter a password the rst time
      you used the network. The security of the wireless network indicates how challenging it would be for a
      hacker to listen to what you are doing on the internet.", :style=> "font: 18px arial,serif ";
      r.br

      wn =r.query("select essid as Name,
      max(if(message like \"%Automatic connection with a profile%\",
      'Automatic','')) as Connection,
      case when max(encryption) = 'AES' then 'High'
           when max(encryption) = 'TKIP' then 'Medium'
           when max(encryption) = 'WEP' then 'Low'
           when max(encryption) = 'None' then 'None'
      end Secure
      from win_wifi_log where user_id=#{user_id} and essid not like ''
      group by essid
      order by count(*) desc,
      essid limit 10")

      if (wn.count==0)
        r.div "You have not connected to any wireless access points recently."
      end





      r.br
    else
      puts "skipping windows section user only has browser data"
    end
    ################################END OF WINDOWS SECTION############################################################
    r.br

    #####both_no_password must change db connections here because it does not have browser data in fieldstudyproduction
    if(r.get_edge_type() == "browser_in_dr3")
      r.change_db_dr3()
    end

    if(r.get_edge_type() == "windows_in_dr3")
      r.change_db_fsp()
    end

    ################################START OF BROWSER SECTION############################################################
    if(not r.get_edge_type() == "windows_only")
      r.div "Internet Usage", :style=> "font: bold 25px arial,serif ";
      r.br
      r.div "
      Security professionals, along with companies like Google (Chrome) and Mozilla (Firefox) have decided
      on a list of default settings for your web browsing that they consider safe. However, it's still up to
      you whether or not you want to change them. To change Chrome settings, click on Preferences. Most
      security settings are listed under Advanced Settings. To change Firefox settings, click on Preferences
      and navigate through the screen that appears. Here we list some of the current settings on your browsers
      we think are important.", :style=> "font: 18px arial,serif ";

      r.br

      # r.query ("select browser_type as '' from browsers where browsers.id in (select browser_id as '' from config where config.browser_id in
      #   (select id as '' from browsers where user_id = #{user_id} )
      #   and config.setting = 'Popup Blocker' group by config.browser_id)")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Chrome' end ''
        from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'chrome')
        and config.setting = 'Popup Blocker' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Firefox' end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'firefox')
        and config.setting = 'Popup Blocker' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Internet Explorer'
        end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'IE')
        and config.setting = 'Popup Blocker' group by config.browser_id")

      #r.div {r.query ("select browser_type as '' from browsers where id = 11")}
      # stmt = r.div {r.query ("select
      # case when browser_type='chrome' then 'Popup blocker is currently: on for Chrome browser'
      # when browser_type='firefox' then 'Popup blocker is currently: on for Firefox browser'
      # end '' from browsers where user_id = #{user_id} order by timestamp desc")}

      r.br
      r.div  "
      Turning the Popup Blocker on increases security and decreases the amount of annoying popups you get.
      When this setting is on, it is harder for sites to open windows without your consent, which is actually
      a security risk: advertisements shown in popups are more likely to contain viruses or other malicious
      code than ads shown within a page.
      ", :style=> "font: 18px arial,serif ";

      r.br
      # r.div {r.query ("select browser_id as '', setting as '',status as '' from config where config.browser_id in
      #   (select id as '' from browsers where user_id = #{user_id} )
      #   and config.setting = 'URL/Search Suggestions' group by config.browser_id")}
      # r.div "Chrome", :style=> "font: bold 18px arial,serif ";
      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Chrome' end ''
        from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'chrome')
        and config.setting = 'URL/Search Suggestions' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Firefox' end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'firefox')
        and config.setting = 'URL/Search Suggestions' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Internet Explorer'
        end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'IE')
        and config.setting = 'URL/Search Suggestions' group by config.browser_id")
      r.br

      r.div "
      URL/Search Suggestions is a service which Google provides to you through the Chome Browser to help
      save you time. However, this means that whenever you use it, you are giving Google permission to see
      which site you are going to, since it must have this data to provide suggestions.", :style=> "font: 18px arial,serif ";

      r.br
      # r.div {r.query ("select browser_id as '', setting as '',status as '' from config where config.browser_id in
      #   (select id as '' from browsers where user_id = #{user_id} )
      #   and config.setting = 'Block Phishing Sites' group by config.browser_id")}
      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Chrome' end ''
        from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'chrome')
        and config.setting = 'Block Phishing Sites' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Firefox' end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'firefox')
        and config.setting = 'Block Phishing Sites' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Internet Explorer'
        end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'IE')
        and config.setting = 'Block Phishing Sites' group by config.browser_id")

      r.br
      r.div "Phishing Sites are websites designed to steal your data. Companies like Norton, Microsoft, and Google
      create lists of known phishing websites, and when this setting is turned on, your browser will block you
      from visiting any websites on these lists. Turning on Block Phishing Sites is a good idea, but don't
      get too comfortable: these lists are largely incomplete, especially for new phishing sites, so you should
      still be careful where you enter your data: do not type your information into sites you do not know or
      reached from a link in your email.", :style=> "font: 18px arial,serif ";

      r.br

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Chrome' end ''
        from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'chrome')
        and config.setting = 'Block Attack Sites' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Firefox' end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'firefox')
        and config.setting = 'Block Attack Sites' group by config.browser_id")

      r.query ("select setting as '',
        case when status='on' then 'is currenty ON for Internet Explorer'
        end '' from config where config.browser_id in
        (select id as '' from browsers where user_id = #{user_id} and browser_type = 'IE')
        and config.setting = 'Block Attack Sites' group by config.browser_id")

      r.br
      r.div "Attack sites are places that have frequently - and successfully - been the target of hackers.  These
      insecure sites are likely to host viruses and malware, and should be avoided. Turning on Block Attack
      Sites blocks sites companies like Norton, Microsoft, and Google have identied. Again, while turning
      this on is a good idea, it is not a failsafe strategy for avoiding danger. You should still be wary about
      which websites you visit: do not click on links from emails, and only download les from sites you are
      familiar or are on the rst few pages of a Google search.", :style=> "font: 18px arial,serif ";
      #browser_id = r.query("select id, browser_type from browsers where user_id = #{user_id} order by timestamp desc")

      r.br

      r.div "Top Websites Visited", :style=> "font: bold 25px arial,serif ";
      r.br
      stmt = r.div {r.query ("SELECT case when isnull(root_domain) then 'N/A' else root_domain end 'Website',
                      COUNT(visits.id) AS 'Number of Visits'
                      from visits, pages where visits.browser_id in (select id as '' from browsers where user_id = #{user_id} order by timestamp desc) and pages.id = visits.page_id
                      GROUP BY root_domain
                      ORDER BY COUNT(visits.id) DESC limit 5 ")}

      r.br

      site_visits_day = r.get_site_visits_day() #add the site visits by day figure to the report
      fig_caption = "Number of websites you visited on each day of the week."
      r.img(file_loc = site_visits_day, img_size = [500, 300], img_caption = fig_caption) ##NOTE if you want image size to be default you must pass nil otherwise img_size will be set to fig_caption

      r.br #new line

      site_visits_hour = r.get_site_visits_hour() #add the site visits by hour figure to the report
      fig_caption = "Number of websites you visited on each hour of the day."
      r.img(file_loc = site_visits_hour, img_size = [500, 300], img_caption = fig_caption)



      r.br
      r.div "What Kinds of Visits Did You Perform?", :style=> "font: bold 25px arial,serif ";
      r.div "There are several different ways you can visit webpages. Typing in the URL and clicking on a bookmark
      are two of the safest ways to visit sites like banks.", :style=> "font: 18px arial,serif ";

      r.br
      stmt = r.div {r.query ("SELECT
                      case when visit_type = 'Generated' then 'Searched via URL bar'
                      when visit_type = 'Bookmark' then 'Bookmark Event'
                      when visit_type = 'Download' then 'Download'
                      when visit_type = 'Typed' then 'Typed in URL'
                      when visit_type = 'Link' then 'Clicked on a Link'
                      end 'Visit Type',
                      COUNT(visits.id) AS 'Number of Visits'
                      from visits, pages where visits.browser_id in (select id as '' from browsers where user_id = #{user_id}) and pages.id = visits.page_id and visits.visit_type in ('Link', 'Typed', 'Download','Bookmark','Generated')
                      GROUP BY visit_type
                      ORDER BY COUNT(visits.id) DESC ")}

      r.br
      r.div "Passwords", :style=> "font: bold 25px arial,serif ";
      r.div "
      It's a good idea to keep track of where you enter passwords, and to use different passwords for each
      website. This ensures that if there is a security breach in one website, criminals cannot access your
      information on others. For example, never use your bank account password for an account on a forum
      or for a video game.", :style=> "font: 18px arial,serif ";


      #res = r.query("select id, browser_type from browsers where user_id = #{user_id} order by timestamp desc")
      stmt = r.div {r.query ("SELECT root_domain as 'Website',
                      COUNT(visits.id) AS `Number of Entry Events`,
                      COUNT(distinct(hash)) AS `Number of Passwords Tried`
                      FROM visits, passwords, pages where visits.browser_id in (select id as '' from browsers where user_id = #{user_id} order by timestamp desc) and passwords.visit_id = visits.id and pages.id = visits.page_id
                      GROUP BY root_domain

                      ORDER BY COUNT(visits.id) DESC limit 15")}

      r.br
      #if(not r.get_edge_type() == "browser_in_dr3" and not r.get_edge_type() == "both_delete")
        r.div "It is recommended to use a password with at least 12 characters(assuming character set of only letters and numbers). A password
        of at least this length is predicted to survive 10^21 guesses. This is approximately how many guesses a password
        should withstand to be able to survive from an attack where a computer program automatically guesses passwords.", :style=> "font: 18px arial,serif ";

        r.br
        passwordFig = r.get_password_length_figure() #add the site visits by day figure to the report
        fig_caption = "Average password length equivalent to a password with a character set size of 62."
        r.img(file_loc = passwordFig, img_size = [500, 300], img_caption = fig_caption) ##NOTE if you want image size to be default you must pass nil otherwise img_size will be set to fig_caption

      #else
      #  puts "skipping password figure for user:#{user_id}"
      #end

    else
      puts "skipping browser section"
    end
    ################################END OF BROWSER SECTION############################################################

  end

  report.save()
end
