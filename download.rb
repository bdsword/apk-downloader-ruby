require 'market_bot'
require 'sqlite3'
require 'securerandom'
require 'time'

File.delete('report.sqlite3') if File.exist?('report.sqlite3')
Dir.mkdir('download') unless File.exist?('download')

db = SQLite3::Database.new 'report.sqlite3'

rows = db.execute <<-SQL
    create table apps (
        app_id text, version text, category text, num_download text, rating float,
        app_size integer, file_path varchar(512), rank integer, update_time datetime, access_time datetime default (datetime(current_timestamp, 'LOCALTIME')),
        primary key (app_id, update_time)
    );
SQL

ignore_categories = ['ANDROID_WEAR']
app_num = 0

MarketBot::Play::Chart::CATEGORIES.each do |category|
    unless ignore_categories.include?(category)
        puts "Category #{category}"
        chart = MarketBot::Play::Chart.new('topselling_free', category, country: 'us', lang: 'en_US')
        chart.update
        chart.result.each do |x|
            app = MarketBot::Play::App.new(x[:package])
            app.update

            file_name = SecureRandom.uuid
            file_path = "./download/#{file_name}.apk"
            result = `python2 -W ignore ./googleplay_api/download.py #{x[:package]} #{file_path}`
            if /^Downloading \d+.\d+(KB|MB|GB)... Done\n$/.match(result).nil?
                puts "Download #{x[:package]} failed..."
                next
            end

            puts db.execute("INSERT INTO apps (app_id, version, category, num_download, rating, update_time, app_size, file_path, rank)
                             VALUES (?,?,?,?,?,?,?,?,?)", [x[:package], app.current_version, app.category, app.installs, app.rating,
                             Time.parse(app.updated).strftime('%Y-%m-%d %H:%M:%S'), File.size(file_path), file_name, x[:rank]])
            app_num = app_num + 1
            puts "##{app_num} finish"
            sleep(5)
        end
        sleep(5)
    end
end


