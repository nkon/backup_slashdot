#!/usr/bin/ruby -Ku

require 'net/http'
require 'uri'
require 'kconv'
require 'date'


$login_name = 'kondou'
$userid     = '7687'
$start      = 0
$op_incr    = 50
$output_dir = File.dirname(__FILE__).gsub(/\/.*$/,"") + "/slashdot3"

$first_year  = 2005
$first_month =   07
$first_day   =   02

$step_day = 10
$sleep_sec = 1

## see   http://slashdot.jp/comments.pl?sid=544329&cid=2017429
## year month date から過去に向かって、数個の日記を検索する。
## %%22 => "  %%3a => :
$list_uri_fmt = "http://slashdot.jp/index2.pl?fhfilter=%%22author%%3a%s%%22+journal&startdate=%04d%02d%02d&view=journal"

$regexp_entry = "http://slashdot.jp/journal/\\d+"
$entry_uri = Hash.new

def get_list(date)
  year  = date.year
  month = date.month
  day   = date.day

  list_uri = sprintf($list_uri_fmt, $login_name, year, month, day)
  puts "get #{list_uri}"
  str = Net::HTTP.get URI.parse(list_uri)

  cnt = 0
  while str.sub!(/#{$regexp_entry}/,'')
    link_uri = $~[0]
    puts "article #{link_uri}"
    $entry_uri[link_uri]=link_uri
    cnt = cnt + 1
  end

#  ### test
#  return $entry_uri if (cnt > 10)

  if ((year <= $first_year) and (month <= $first_month) and (day <= $first_day))
    return $entry_uri
  else
    sleep($sleep_sec)                    ## To reduce server load
    return get_list(date - $step_day)
  end
end



def cutout_article(str)
  # 不要な要素の削除。*? は最短のマッチ, /xm は複数行マッチ
  str.gsub!(/\<script(.*?)\<\/script\>/xm,'')
  str.gsub!(/\<style(.*?)\<\/style\>/xm,'')
  str.gsub!(/\<footer(.*?)\<\/footer\>/xm, '')
  str.gsub!(/\<nav(.*?)\<\/nav\>/xm, '')
  str.gsub!(/\<form(.*?)\<\/form\>/xm,'')
  str.gsub!(/\<section\sclass=\"grid_24\"(.*?)\<\/section\>/xm, '')
  str.gsub!(/\<section\sclass=\"bq\"\>(.*?)\<\/section\>/xm, '')

  return str
end

link = Hash.new
day  = Hash.new
title= Hash.new

puts "output = #{$output_dir}"

######
# get list
get_list(Date.today)


######
# get article and analysis
$entry_uri.each_key{|uri|
  uri =~ /\d+$/
  number = $~[0]

  filename = "#{$output_dir}/#{number}.html"

#  if (!File.exist?(filename)) then
    str = Net::HTTP.get URI.parse(uri)
    puts "get #{uri}"
    str =~ /datetime\=\"(\d+)\-(\d+)\-(\d+)/
    y = $1
    m = $2
    d = $3
    daystr = "#{y}年#{m}月#{d}日"

    str =~ /<title>(.*)\s+\|/
    titlestr = $1

    str = cutout_article(str)
    puts "day #{daystr} #{titlestr}"

    link[uri] = daystr
    day[uri]  = number
    title[uri]= titlestr

    open(filename,'w') {|f|
      f.print str
    }

    sleep($sleep_sec)      # to reduce server load

#  end
}

#####
# generate index.html
index_fname = "#{$output_dir}/index.html"
open(index_fname, 'w') {|f|

  f.puts "<ul>"

  $entry_uri.keys.sort.each{|key|
    if (link[key]) then
      f.puts "<li><a href=\"#{day[key]}.html\">#{link[key]} #{title[key]}</a></li>"
    end
  }

  f.puts "</ul>"

}


