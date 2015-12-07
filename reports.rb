require_relative 'report_builder'

### Account list. Admin status and password protection pending
def account_list(user_id, path, dbh)
  fdh=path
  fdh.puts "\\section*{List of Computer Accounts}"
  stmt = dbh.prepare("select distinct system_user from win_logon_log
                     where user_id =? and not system_user like 'SYSTEM'
                     and not system_user like 'LOCAL SERVICE' and
                     not system_user like 'ANONYMOUS LOGON' and not
                     system_user like 'NETWORK SERVICE'")
  res = stmt.execute(user_id)
  stmt = dbh.prepare("select shutdown_without_logon from
                     win_security_settings
                     where user_id =? order by id desc limit 1")
  res2 = stmt.execute(user_id)
  fdh.puts "\\begin{tabular}{l l}"
  fdh.puts "Account Name & Logon Required
  for Shutdown \\\\"
  fdh.puts "\\hline"
  shutdown = ''
  unlock = ''
  res2.each do |row|
    if row[0] == 1
      shutdown = "Logon not required"
    else
      shutdown = "Logon required"
    end
    if row[1] == 1
      unlock = "Logon not required"
    else
      unlock = "Logon required"
    end

  end
  res.each do |row|
    name = row[0]
    fdh.puts "#{name} & #{shutdown}\\\\"
  end
  fdh.puts "\\end{tabular}"
  fdh.puts "\\vskip 2em"
end

def browser_data(hours, missing=true)
    q = "select b.id as browser_id, b.user_id, u.identifier as subject"
    q += ", s.visits, s.url_loads, s.tab_forks, s.addons, s.config, s.download, s.history, s.other, s.password, s.security " unless missing
    q += " from browsers b left join "\
         "(select local_id, "\
         "sum(tag = 'log') as visits, "\
         "sum(tag = 'on_visit') as url_loads, "\
         "sum(tag = 'tab_fork') as tab_forks, "\
         "sum(tag = 'addon_installs' or tag = 'addon_updates') as addons,  "\
         "sum(tag = 'config') as config, "\
         "sum(tag = 'download') as download, "\
         "sum(tag = 'history') as history, "\
         "sum(tag = 'other') as other, "\
         "sum(tag = 'password') as password, "\
         "sum(tag = 'security') as 'security' "\
         "from server_log "
    q += "where time_to_sec(timediff(#{today}, timestamp)) < 60*60*#{hours} and timestamp < #{today} " unless hours == 0
    q += "group by local_id) s "\
         "on b.local_id = s.local_id "\
         "left join users u on b.user_id = u.id  "
    if missing
      q += "where s.local_id is null"
    else
      q += "where s.local_id is not null"
    end
    q += " and b.id not in (select distinct o.browser_id from browsers b, other o where o.comment = 'Number of cookies = 0' and b.id = o.browser_id and b.browser_type = 'chrome')"
    q
end

def win_logs(table, hours=0)
  q = "select user_id, count(*) as logs from #{table} "
  q += "where time_to_sec(timediff(#{today}, timestamp)) < 60*60*#{hours} and timestamp < #{today} " unless hours == 0
  q += "group by user_id"
  q
end

def win_interest_logs(hours = 0, missing=true)
  q = "select u.id, u.identifier as subject, f.logs as Firewall, a.logs as Applications, p.logs as Processor, proc.logs as Process, "\
      "sp.logs as 'Security Products', ss.logs as 'Security Settings', l.logs as logins FROM users u "
  q += "LEFT JOIN (#{win_logs('win_firewall', hours)}) f on u.id = f.user_id "
  q += "LEFT JOIN (#{win_logs('win_installed_applications', hours)}) a on u.id = a.user_id "
  q += "LEFT JOIN (#{win_logs('win_processor_log', hours)}) p on u.id = p.user_id "
  q += "LEFT JOIN (#{win_logs('win_process_log', hours)}) proc on u.id = proc.user_id "
  q += "LEFT JOIN (#{win_logs('win_security_products', hours)}) sp on u.id = sp.user_id "
  q += "LEFT JOIN (#{win_logs('win_security_settings', hours)}) ss on u.id = ss.user_id "
  q += "LEFT JOIN (#{win_logs('win_logon_log', hours)}) l on u.id = l.user_id "
  q += "WHERE "
  q += "NOT " if missing
  q += "(f.logs is not null or a.logs is not null or p.logs is not null or proc.logs is not null or sp.logs is not null or ss.logs is not null or l.logs is not null)"
  q
end

def daily_report(client, user_id, hours = 0)
  report = UserReport.new(client, user_id) do |r|
    if( not r.make_graphs()) ###This line of code takes awhile to run(4seconds ish)
      return false #This report can not be made because the user does not have enough data
    end

    img_dim = [541, 148]
    r.img(file_loc = "bitlab_wide.jpg", img_size = img_dim)

    r.h1 {r.span "Computer Security Report", :style=> "color:#8C001A";}

    d = Time.now.strftime("%B %-d, %Y")
    r.h2 {r.span "Report created: #{d}", :style=> "color:#909090 ";}

    r.h2 "Basic Facts"
   r.h3 "Your Computer"
   r.div {r.span "Manufacturer: #{r.q("select manufacturer from win_computer_hardware where user_id=#{user_id} limit 1")}";}
   r.div {r.span "Model: #{r.q("select model from win_computer_hardware where user_id=#{user_id} limit 1")}";}

   os = r.q("select version from win_operating_system where user_id =#{user_id} limit 1")
   if os.include? "6.1"
     r.div {r.span "Operating System: Windows 7";}
   elsif os.include? "6.2"
     r.div {r.span "Operating System: Windows 8";}
   else
     r.div {r.span "Operating System: Windows 8.1";}
   end

   begin
     usage_fig_loc = r.get_usage_figure() #this block of code adds the usage figure to the report
     img_dim = [700, 400]
     fig_caption = "Caption: graph of user usage vs average usage of all users"
     r.img(file_loc = usage_fig_loc, img_size = img_dim, img_caption = fig_caption)
   rescue
     puts "skipping usage figure for user_id: #{user_id}"
   end


   r.h2 "User Account Control"
   r.div "When a new piece of software asks for the right to make changes to your computer, such as when
   installing software, Windows can show you a warning and ask if this piece of software should be allowed
   to make changes. This dialog is called a User Account Control (UAC) dialog. By default Windows
   displays the UAC dialog by turning the screen black and showing a dialog window asking for your
   approval. It is possible for either you or software acting on your behalf to turn off these warnings.
   You can nd these settings by going to the Control Panel, selecting the System and Security
   category, and then clicking on Change User Account Control settings Action Center, or
   search for Change User Account Control settings in the search bar.
   It is recommended that you keep these warnings on. When they are off, any piece of software can
   make changes to important settings on your computer without your knowledge."
   warnings = r.q("select if(consent_prompt_behavior_admin=
                     'ElevateWithoutPrompting','No','Yes') as admin,
                      if(consent_prompt_behavior_user=
                      'AutoDenyElevationRequests','Deny all',
                      if(consent_prompt_behavior_user='Undefined','No','Yes')
                      ) as user
                      from win_security_settings where user_id
                      =#{user_id} order by id desc limit 1")
   if (warnings == "Yes") #warnings[0] == "Yes" and warnings[1] == "Yes")
     r.div {r.span "The User Account Control warnings are TURNED ON for your computer";}
   elsif (warnings[0] == "Yes" or warnings[1] == "Yes")
     r.div {r.span "The User Account Control warnings are SOMETIMES ON for your computer";}
   else
     r.div {r.span "The User Account Control warnings are TURNED OFF for your computer";}
   end

    r.h2 "Windows Updates"
    r.div "Microsoft, the company that produces Windows, occasionally nds issues with their software and releases
    updates to x the issues. The recommended and default setting on Windows is to automatically check
    for recommended and security updates and then install them. Microsoft also releases optional
    updates, and these are not installed unless you change your settings or manually install them.
    You can nd these settings by going to the Control Panel, selecting the System and Security category,
    and clicking on Turn automatic updating on or off under Windows Update, or by searching Turn
    automatic updating on or off in the search bar."

    res = r.q("select update_notification_level,
                         update_schedule_install_day,
                         update_schedule_install_time,
    update_include_recommended, update_non_admin_elevated,
    update_featured_enabled from win_security_settings where
    user_id=#{user_id} limit 1")

    #TODO check for days
        if(res == "NotConfigured" or res == "Disabled")
          r.div "You DO NOT have the recommended update settings."


          r.div  "Your computer:"
          r.div  "Auto checks for updates - No"
        else
          r.div  "You HAVE the recommended update settings."

          r.div  "Your computer: "
          r.div  "Auto-Checks for updates - Every day"
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

    windows_updates = r.get_updates()
    fig_caption = "<b>FIG5: </b>number of windows updates downloaded on each date"
    img_dim = [600, 300]
    r.img(file_loc = windows_updates, img_size = img_dim, img_caption = fig_caption)

    r.h2 "Software Updates"
    r.div "Using out-of-date versions of software may pose serious security risks to your computer. Your risk of
    getting infected with viruses or malware is less if all of your software is up to date. Internet Browsers,
    Java, and Adobe Reader are most likely to be out-of-date. For your computer:"

    r.div "Name   Updated"
    chr = r.q("SELECT date(min(local_time)) as tim,display_name,
                    version FROM win_installed_applications where
    user_id = #{user_id} and display_name like 'Google Chrome'
    group by display_name order by id desc limit 1")

      if chr != "35.0.1916.153"
        r.div "Google Chrome - No "
      else
        r.div "Google Chrome - Yes "
      end

    f = r.q("SELECT date(min(local_time)) as tim,display_name,
                    version FROM win_installed_applications where
    user_id = #{user_id} and display_name like '%Firefox%'
    group by display_name order by id desc limit 1")

      if f != "30.0"
        r.div "Mozilla Firefox - No"
      else
        r.div "Mozilla Firefox - Yes"
      end

    have_java = false
    j = r.q("SELECT date(min(local_time)) as tim,
                    display_name,version FROM win_installed_applications
                    where user_id = #{user_id} and display_name like
                    '%Java 7 Update%' group by display_name order by
                    id desc limit 1")


      have_java = true
      if j != "Java 7 Update 60" or j != "Java 7 Update 55"
        r.div "Java* - No"
      else
        r.div "Java* - Yes"
      end

    a= r.q("SELECT date(min(local_time)) as tim,
    substring_index(display_name, ' ', 3) as display_name,
    version FROM win_installed_applications where user_id =
    #{user_id} and display_name like '%Adobe Reader%'
    group by display_name order by id desc limit 1")

    if a != "11.0.07" or a != "10.1.10" or a != "9.5.5" or a != "8.3.1"
      r.div "Adobe Reader - No"
    else
      r.div "Adobe Reader - Yes"
    end

    r.div "*Java is a program that is not normally used by computer
    users directly. It is a program that other programs need to function."

    r.h2 "Firewalls"
    r.div "A rewall is a program that prevents other computers on the internet from interacting with your computer
    unless you interact with them rst. You should have a rewall installed on your computer and have it
    on at all times. Windows comes pre-installed with a rewall; however, you can also install your own.
    You can nd these settings by going to the Control Panel, selecting the System and Security category
    and then clicking on Check rewall status under Windows Firewall or by searching Check rewall
    status in the search bar. The following are the rewall(s) installed on your computer:"


    res = r.query("select
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
    where user_id=#{user_id} and sub.smax = snapshot")

    r.h2 "Antivirus"
    r.div "Antivirus software protects your computer from viruses by actively scanning your computer for potentially
    infected software. You should install and turn on automatic updates so that you can have the strongest
    protection from these security threats.If you have multiple antivirus programs installed, only one should be running.
    If you have multiple antivirus programs running at the same time, they can attack each other and put your computer's
    security at risk. The following are the antivirus program(s) installed on your computer:"

    res = r.query("select name as Name,
                  case when running_raw = '10' then 'Yes'
                       when running_raw = '01' then 'No'
                  end Running,
                  case when up_to_date_raw = '00' then 'Yes' else 'No'
                  end Updated
                   from win_security_products,
                   (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
                   as sub
                   where user_id=#{user_id}
                   and type = 'AntiVirusProduct' and sub.smax = snapshot")
    r.div (res[0])

    count = r.q("select count(name) from win_security_products,
            (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
            as sub
            where user_id=#{user_id}
            and type = 'AntiVirusProduct' and sub.smax = snapshot")

    if count == '0'
      r.div "Currently, you DO NOT have any anti-spyware software
      installed on your computer. We recommend that you consider
      installing one of the following free anti-spyware programs that have
      received high ratings to protect your computer: Ad-Aware Free Antivirus, Malwarebytes Anti-Malware, Emsisoft Anti-Malware Free"

    elsif count == '1'
      r.div "You have multiple antivirus programs running at the same time. This could potentially put your computer at risk"
    else
      r.div "Your antivirus is in a GOOD state"
    end


    r.h2 "Anti-spyware"
    r.div "Anti-spyware software looks for potentially malicious software on your computer that might steal per-
    sonal information like passwords or bank credentials. Many antivirus programs come with anti-spyware
    included.
    If you have multiple anti-spyware programs installed, only one should be running. If you have multiple
    anti-spyware programs running at the same time, they can attack each other and put your computer's
    security at risk.
    The following are the anti-spyware program(s) installed on your computer:"
    res = r.query("select name as Name,
                  case when running_raw = '10' then 'Yes'
                       when running_raw = '01' then 'No'
                  end Running,
                  case when up_to_date_raw = '00' then 'Yes' else 'No'
                  end Updated
                   from win_security_products,
                   (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
                   as sub
                   where user_id=#{user_id}
                   and type = 'AntiSpywareProduct' and sub.smax = snapshot")
    r.div (res[0])
    count = r.q("select count(name) from win_security_products,
            (select max(snapshot) as smax from win_security_products where user_id=#{user_id})
            as sub
            where user_id=#{user_id}
            and type = 'AntiSpywareProduct' and sub.smax = snapshot")

    if count == '0'
      r.div "Currently, you DO NOT have any anti-spyware software
      installed on your computer. We recommend that you consider
      installing one of the following free anti-spyware programs that have
      received high ratings to protect your computer: Ad-Aware Free Antivirus, Malwarebytes Anti-Malware, Emsisoft Anti-Malware Free"

    elsif count == '1'
      r.div "You have multiple antivirus programs running at the same time. This could potentially put your computer at risk"
    else
      r.div "Your antivirus is in a GOOD state"
    end


    r.h2 "Wireless Networks"
    r.div "A wireless network is a network you connect to when you want to access the internet without using an
    actual wire. Below is a table of wireless networks that your computer has connected to. An automatic
    connection means that your computer connected to this wireless network without asking you at least
    once. Otherwise, the connection is manual, and your computer always asks you before connecting to
    this network. A password protected network is one where you had to enter a password the rst time
    you used the network. The security of the wireless network indicates how challenging it would be for a
    hacker to listen to what you are doing on the internet."

    res = r.query("select essid as Name,
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


    r.h2 "Internet Usage"
    r.div "\n\n
    Security professionals, along with companies like Google (Chrome) and Mozilla (Firefox) have decided
    on a list of default settings for your web browsing that they consider safe. However, it's still up to
    you whether or not you want to change them. To change Chrome settings, click on Preferences. Most
    security settings are listed under Advanced Settings. To change Firefox settings, click on Preferences
    and navigate through the screen that appears. Here we list some of the current settings on your browsers
    we think are important."

    stmt = r.query ("select
    case when browser_type='chrome' then 'Popup blocker is currently: on for Chrome browser'
    when browser_type='firefox' then 'Popup blocker is currently: on for Firefox browser'
    end '' from browsers where user_id = #{user_id} order by timestamp desc")

    r.div  "\n\n
    Turning the Popup Blocker on increases security and decreases the amount of annoying popups you get.
    When this setting is on, it is harder for sites to open windows without your consent, which is actually
    a sercurity risk: advertisements shown in popups are more likely to contain viruses or other malicious
    code than ads shown within a page.
    "
    stmt = r.query ("select
    case when browser_type='chrome' then 'URL/Search Suggestions is currently: on for Chrome browser'

    end '' from browsers where user_id = #{user_id} order by timestamp desc")

    r.div "\n\n
    URL/Search Suggestions is a service which Google provides to you through the Chome Browser to help
    save you time. However, this means that whenever you use it, you are giving Google permission to see
    which site you are going to, since it must have this data to provide suggestions."

    stmt = r.query ("select
    case when browser_type='chrome' then 'Block Phishing Sites is currently: on for Chrome browser'
    when browser_type='firefox' then 'Block Phishing Sites is currently: on for Firefox browser'
    end '' from browsers where user_id = #{user_id} order by timestamp desc")


    r.div "\n\nPhishing Sites are websites designed to steal your data. Companies like Norton, Microsoft, and Google
    create lists of known phishing websites, and when this setting is turned on, your browser will block you
    from visiting any websites on these lists. Turning on Block Phishing Sites is a good idea, but don't
    get too comfortable: these lists are largely incomplete, especially for new phishing sites, so you should
    still be careful where you enter your data: do not type your information into sites you do not know or
    reached from a link in your email."

    stmt = r.query ("select
    case when browser_type='chrome' then 'Block Attack Sites is currently: on for Chrome browser'
    when browser_type='firefox' then 'Block Attack Sites is currently: on for Firefox browser'
    end '' from browsers where user_id = #{user_id} order by timestamp desc")

    r.div "\n\nAttack sites are places that have frequently - and successfully - been the target of hackers.  These
    insecure sites are likely to host viruses and malware, and should be avoided. Turning on Block Attack
    Sites blocks sites companies like Norton, Microsoft, and Google have identied. Again, while turning
    this on is a good idea, it is not a failsafe strategy for avoiding danger. You should still be wary about
    which websites you visit: do not click on links from emails, and only download les from sites you are
    familiar or are on the rst few pages of a Google search."
    #browser_id = r.query("select id, browser_type from browsers where user_id = #{user_id} order by timestamp desc")

    r.h3 "Top Websites Visited"
    stmt = r.query ("SELECT root_domain as 'Website',
                    COUNT(visits.id) AS 'Number of Visits'
                    from visits, pages where visits.browser_id in (select id as '' from browsers where user_id = #{user_id} order by timestamp desc) and pages.id = visits.page_id
                    GROUP BY root_domain
                    ORDER BY COUNT(visits.id) DESC limit 5 ")


    r.h3 "What Kinds of Visits Did You Perform?"
    r.div "There are several different ways you can visit webpages. Typing in the URL and clicking on a bookmark
    are two of the safest ways to visit sites like banks."

    stmt = r.query ("SELECT
                    case when visit_type = 'Generated' then 'Searched via URL bar'
                    when visit_type = 'Bookmark' then 'Bookmark Event'
                    when visit_type = 'Download' then 'Download'
                    when visit_type = 'Typed' then 'Typed in URL'
                    when visit_type = 'Link' then 'Clicked on a Link'
                    end 'Visit Type',
                    COUNT(visits.id) AS 'Number of Visits'
                    from visits, pages where visits.browser_id in (select id as '' from browsers where user_id = #{user_id} order by timestamp desc7) and pages.id = visits.page_id and visits.visit_type in ('Link', 'Typed', 'Download','Bookmark','Generated')
                    GROUP BY visit_type
                    ORDER BY COUNT(visits.id) DESC ")


    r.h3  "Passwords"
    r.div "
    It's a good idea to keep track of where you enter passwords, and to use different passwords for each
    website. This ensures that if there is a security breach in one website, criminals cannot access your
    information on others. For example, never use your bank account password for an account on a forum
    or for a video game."

    #res = r.query("select id, browser_type from browsers where user_id = #{user_id} order by timestamp desc")
    stmt = r.query ("SELECT root_domain as 'Website',
                    COUNT(visits.id) AS `Number of Entry Events`,
                    COUNT(distinct(hash)) AS `Number of Passwords Tried`
                    FROM visits, passwords, pages where visits.browser_id in (select id as '' from browsers where user_id = #{user_id} order by timestamp desc) and passwords.visit_id = visits.id and pages.id = visits.page_id
                    GROUP BY root_domain
                    ORDER BY COUNT(visits.id) DESC limit 15")

    #
    #     # Check for browsers not associated with users
    #     r.query "select id as browser_id, user_id, browser_type, install_version, timestamp, comment from browsers where user_id = (select id from users where identifier is null) and id not in (select distinct o.browser_id from browsers b, other o where o.comment = 'Number of cookies = 0' and b.id = o.browser_id and b.browser_type = 'chrome')" do
    #       r.h3 { r.span "X ", :style => "color: red"; r.text "We have #{r.count} browsers not associated with a user :" }
    #       r.div "We cannot tell which subject sent us this data"
    #       r.div "This does not include browsers that are in the database, but have sent a 'Number of cookies = 0' message", :style => "font-size: 75%"
    #       r.results
    #       # r.no_results { r.h3 { r.span "√ ", :style => "color: green"; r.text "All browsers are correctly associated with a user" } }
    #     end
    #
    #     # Check to make sure we have data from all browsers
    #     r.query 'select b.user_id, b.id as browser_id, b.browser_type, u.identifier as subject from browsers b '\
    #             'LEFT JOIN (select browser_id, count(*) as num_visits, count(distinct page_id) as num_pages from  visits group by browser_id) v on b.id = v.browser_id '\
    #             'LEFT JOIN (select browser_id, count(*) as num_url_loads from on_visit group by browser_id) l on b.id = l.browser_id '\
    #             'LEFT JOIN (select browser_id, count(*) as num_tab_forks from tab_fork group by browser_id) f on b.id = f.browser_id '\
    #             'LEFT JOIN users u on b.user_id = u.id '\
    #             'where not (v.num_visits is not null or v.num_pages is not null or l.num_url_loads is not null or f.num_tab_forks is not null) '\
    #             'and b.id not in (select distinct o.browser_id from browsers b, other o where o.comment = "Number of cookies = 0" and b.id = o.browser_id and b.browser_type = "chrome") '\
    #             'order by b.user_id, b.id, b.browser_type' do
    #       # r.no_results { r.h3 { r.span "√ ", :style => "color: green"; r.text "All browsers have sent pageview data!" } }
    #       r.h3 { r.span "X ", :style => "color: red"; r.text "#{r.count} browsers have never sent any pageview data:" }
    #       r.div "We cannot tell whether these users never used their browser, or whether we just aren't getting data from them"
    #       r.div "This does not include browsers that are in the database, but have sent a 'Number of cookies = 0' message", :style => "font-size: 80%"
    #       r.results
    #     end
    #
    #     # Report on browsers with cookie=0
    #     r.query 'select distinct browser_id from other o, browsers b where o.comment = "Number of cookies = 0" and b.id = o.browser_id and b.user_id = (select id from users where identifier is null)' do
    #       # r.no_results { r.h3 { r.span "√ ", :style => "color: green"; r.text "The cookie=0 problem has not occured" } }
    #       r.h3 { r.span "X ", :style => "color: red"; r.text "We have #{r.count} browsers that have reported 0 cookies and are not associated with users" }
    #       r.div "This is a known bug", :style => "font-size: 80%"
    #     end
    #
    #     # Check to make sure browsers are still uploading data (in the last 24 hours)
    #     r.query browser_data(hours, true) do
    #       # r.no_results { r.h3 { r.span "√ ", :style => "color: green"; r.text "All browsers have uploaded data in the last #{hours} hours" } }
    #       r.h3 { r.span "X ", :style => "color: red"; r.text "#{r.count} browsers have not uploaded any browser data in the last 24 hours" }
    #       r.div "These users might not be using their computer, or might have accidentally disabled the plugin?"
    #       r.results
    #     end
    #
    #     # Check to make sure we have windows data from all computers
    #     r.query 'select u.id, u.identifier as subject from users u left join
    #              (select computer_id, user_id, count(*) as logs from win_server_log group by computer_id) l
    #              on u.id = l.user_id
    #              where u.identifier is not null and l.computer_id is null' do
    #       # r.no_results { r.h3 { r.span "√ ", :style => "color: green"; r.text "All users have uploaded windows data" } }
    #       r.h3 { r.span "X ", :style => "color: red"; r.text "#{r.count} users are not uploading any data from windows" }
    #       r.div "These users might not have installed properly, or might never use this computer"
    #       r.results
    #     end
    #
    #     # Check to make sure windows clients are still uploading data
    #     r.query "select u.id, u.identifier as subject from users u left join
    #              (select computer_id, user_id, count(*) as logs from win_server_log where time_to_sec(timediff(#{today}, timestamp)) < 60*60*#{hours} and timestamp < #{today} group by computer_id) l
    #              on u.id = l.user_id
    #              where u.identifier is not null and l.computer_id is null" do
    #       # r.no_results { r.h3 { r.span "√ ", :style => "color: green"; r.text "All users have uploaded windows data in the last 24 hours" } }
    #       r.h3 { r.span "X ", :style => "color: red"; r.text "#{r.count} users have not uploaded any data from windows in the last 24 hours" }
    #       r.div "These users might not be using their computer, or they might have disabled the windows client?"
    #       r.results
    #     end
    #
    #
    #
    #     # ######## Summary of Data in the last 24 hours###########
    #     r.hr
    #     r.h2 "Summary of data received in the last 24 hours"
    #
    #     # Summary of browser data (in the last 24 hours)
    #     r.query browser_data(hours, false) do
    #       r.no_results { r.h3 "No browsers have uploaded data in the last #{hours} hours" }
    #       r.h3 "#{r.count} browsers have uploaded data in the last 24 hours"
    #       r.results
    #     end
    #
    #     # Summary of windows data that we expect to change (in the last 24 hours)
    #     r.query win_interest_logs(hours, false) do
    #       r.no_results { r.h3 "No users have uploaded windows logs in the last 24 hours" }
    #       r.h3 "#{r.count} computers have uploaded windows logs in the last 24 hours"
    #       r.results
    #     end
    #
    #     # ######## Summary of Data Overall ###########
    #     r.hr
    #     r.h2 "Summary of data received since the beginning of the study"
    #
    #     # Summarize total browser pageview data
    #     r.query 'select b.user_id, u.identifier as subject, b.id as browser_id, b.browser_type, v.num_visits as visits, v.num_pages as pages, l.num_url_loads as url_loads, f.num_tab_forks as tab_forks from browsers b '\
    #             'LEFT JOIN (select browser_id, count(*) as num_visits, count(distinct page_id) as num_pages from  visits group by browser_id) v on b.id = v.browser_id '\
    #             'LEFT JOIN (select browser_id, count(*) as num_url_loads from on_visit group by browser_id) l on b.id = l.browser_id '\
    #             'LEFT JOIN (select browser_id, count(*) as num_tab_forks from tab_fork group by browser_id) f on b.id = f.browser_id '\
    #             'LEFT JOIN users u on b.user_id = u.id '\
    #             'where v.num_visits is not null or v.num_pages is not null or l.num_url_loads is not null or f.num_tab_forks is not null '\
    #             'order by b.user_id, b.id, b.browser_type' do
    #       r.no_results { r.h2 "No browsers have any clickstream data!" }
    #       r.h3 "How much clickstream data do we have in total from each browser?"
    #       r.results
    #     end
    #
    #     # Summarize total windows data
    #     r.query win_interest_logs(0, false) do
    #       r.no_results { r.h3 "No users have uploaded windows logs of interest" }
    #       r.h3 "How much windows data do we have?"
    #       r.results
    #     end

    # r.make_graphs() ###This line of code takes awhile to run(10seconds ish) and can be commented out IFF the figures are already generated
    #
    # windows_updates = r.get_updates()
    # fig_caption = "<b>FIG5: </b>number of windows updates downloaded on each date"


    site_visits_day = r.get_site_visits_day() #add the site visits by day figure to the report
    fig_caption = "<b>FIG3:</b> number of websites you visited on each day of the week."
    r.img(file_loc = site_visits_day, img_size = nil, img_caption = fig_caption) ##NOTE if you want image size to be default you must pass nil otherwise img_size will be set to fig_caption

    r.br #new line

    site_visits_hour = r.get_site_visits_hour() #add the site visits by hour figure to the report
    fig_caption = "<b>FIG4:</b> number of websites you visited on each hour of the day."
    r.img(file_loc = site_visits_hour, img_size = nil, img_caption = fig_caption)


  end

  report.save()
end
