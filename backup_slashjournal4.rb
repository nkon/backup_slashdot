#!/usr/bin/ruby -Ku
# coding:utf-8
# -*- coding: utf-8 -*-

require 'net/http'
require 'uri'
require 'kconv'
require 'date'


$login_name = 'kondou'
$userid     = '7687'
$start      = 0
$op_incr    = 50
$output_dir = File.dirname(__FILE__).gsub(/\/.*$/,"") + "/slashdot4"

$first_year  = 2005
$first_month =   07
$first_day   =   02

$step_day = 10
$sleep_sec = 1

$max_page = 30

## see   http://slashdot.jp/comments.pl?sid=544329&cid=2017429
## year month date から過去に向かって、数個の日記を検索する。
## %%22 => "  %%3a => :
## magic code color=black
$list_uri_fmt = "http://srad.jp/index2.pl?color=blue&fhfilter=%%22author%%3a%s%%22+journal&page=%d"

$regexp_entry = "http://srad.jp/~kondou/journal/\\d+"
$entry_uri = Hash.new

def get_list(page)
  list_uri = sprintf($list_uri_fmt, $login_name, page)
  puts "get #{list_uri}"
  str = Net::HTTP.get URI.parse(list_uri)

  cnt = 0
  while str.sub!(/#{$regexp_entry}/,'')
    link_uri = $~[0]
    puts "article #{link_uri}"
    $entry_uri[link_uri]=link_uri
    cnt = cnt + 1
  end

  if (page > $max_page)
    return $entry_uri
  else
    sleep($sleep_sec)
    return get_list(page+1)
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
$entry_uri = get_list(0)


######
# get article and analysis
$entry_uri.each_key{|uri|
  uri =~ /\d+$/
  number = $~[0]

  filename = "#{$output_dir}/#{number}.html"

#  if (!File.exist?(filename)) then
    str = Net::HTTP.get URI.parse(uri)
    str.force_encoding('utf-8')

    puts "get #{uri}"
    str =~ /datetime\=\"(\d+)\-(\d+)\-(\d+)/
    y = $1
    m = $2
    d = $3
    daystr = "#{y}年#{m}月#{d}日"

    str =~ /<title>(.*)\s+\|/u
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


