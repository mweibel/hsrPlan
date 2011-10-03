#!/usr/bin/env ruby
# 
# Fetch all modules
# 
# @author Michael Weibel <michael.weibel@gmail.com>
# @copyright 2011 Michael Weibel
#

require 'sqlite3'
require 'nokogiri'

class ModuleFetcher
#	MODULE_LIST_URL = "https://unterricht.hsr.ch/staticWeb/I/STD_05/Module.html"
#	ECTS_PER_CATEGORY_URL = "https://unterricht.hsr.ch/staticWeb/I/STD_05/MinKperKat.html"
	MODULE_LIST_URL = "static/Module.html"
	ECTS_PER_CATEGORY_URL = "static/MinKperKat.html"
	DB_PATH = "db/"
	
	def initialize()
		@db = SQLite3::Database.new(DB_PATH + "modules.db")
		create_tables
		
		fetch_categories
		fetch_modules_per_category
		
		@db.close
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
		doc = open_url(ECTS_PER_CATEGORY_URL)
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
		doc = open_url(MODULE_LIST_URL)
		categories = doc.xpath("//h2")
		
		categories.each do |category|
			modules_in_category = category.next_element.xpath("li")
			
			category_name = category.to_str
			category_id = add_category_ifnotexists(category_name, 0)
			modules_in_category.each do |modul|	
				link = modul.xpath("a")
				name = link.text
				ects = "1"
#				ects = fetch_etcs_from_module url
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
		f = File.open(url)
		doc = Nokogiri::HTML(f)
		f.close
		
		return doc
	end
end

ModuleFetcher.new