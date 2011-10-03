#!/usr/bin/env ruby
# 
# Fetch all modules
# 
# @author Michael Weibel <michael.weibel@gmail.com>
# @copyright 2011 Michael Weibel
#

require 'sqlite3'
require 'nokogiri'
require 'open-uri'

class ModuleFetcher
	MODULE_LIST_FILE = "Module.html"
	ECTS_PER_CATEGORY_FILE = "MinKperKat.html"
	DB_PATH = "db/"
	
	def initialize(studyCourseUrl)
		@studyCourseUrl = studyCourseUrl
		@db = SQLite3::Database.new(DB_PATH + "modules.db")
		create_tables
		
		fetch_categories
		fetch_modules_per_category
		
		@db.close
	end
	
	def get_full_path(file)
		@studyCourseUrl + "/" + file
	end
	
	def create_tables
		@db.execute("CREATE TABLE IF NOT EXISTS categories (
			id  INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
			name VARCHAR(255) NOT NULL, 
			ects INT NOT NULL)")
		@db.execute("CREATE TABLE IF NOT EXISTS modules (
			id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, 
			category_id INTEGER NOT NULL, 
			name VARCHAR(255) NOT NULL, 
			ects INTEGER NOT NULL)")
	end
	
	def fetch_categories	
		doc = open_url(get_full_path(ECTS_PER_CATEGORY_FILE))
		nodes = doc.xpath("//table/tbody/tr")
		
		nodes.each do |node|
			if node.xpath("td/strong").length == 0
				td = node.xpath("td")
				name = td[0].to_str
				ects = td[1].to_str
				
				add_category_ifnotexists(name, ects)
			end
		end
	end
	
	def add_category_ifnotexists(name, ects)
		result = @db.execute("SELECT id FROM categories WHERE name=?", name)
		if result.length == 0
			result = @db.execute("INSERT INTO categories (name, ects) VALUES (?, ?)", name, ects)
			category_id = @db.last_insert_row_id
		else
			category_id = result.first[0]
		end
		return category_id
	end
	
	def fetch_modules_per_category
		doc = open_url(get_full_path(MODULE_LIST_FILE))
		categories = doc.xpath("//h2")
		
		categories.each do |category|
			modules_in_category = category.next_element.xpath("li")
			
			category_name = category.to_str
			category_id = add_category_ifnotexists(category_name, 0)
			modules_in_category.each do |modul|	
				link = modul.xpath("a")
				name = link.text
				ects = fetch_etcs_from_module link.xpath("@href")
				result = @db.execute("SELECT m.id, m.name, m.ects FROM modules m WHERE name = ?", name)
				if result.length == 0
					@db.execute("INSERT INTO modules (category_id, name, ects) VALUES (?, ?, ?)", category_id, name, ects)
				else
					@db.execute("UPDATE modules SET ects = ? WHERE id = ?", ects, result.first[0])
				end
			end
		end
	end
	
	def fetch_etcs_from_module(link)
		"0"
	end
	
	def open_url(url)
		file = File.open(url)
#		file = open(url)
		doc = Nokogiri::HTML(file)
		file.close
		
		return doc
	end
end