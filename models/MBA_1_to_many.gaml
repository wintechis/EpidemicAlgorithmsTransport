/**
* Name: MBA_1_to_many
* Author: Sebastian Schmid
* Description: Simple, local communication from agent to all its neighbors
* Tags: 
*/


@no_warning
model MBA_1_to_many

import "Station_Item.gaml"

global{
	
	init{
							
		create transporter number: no_transporter;	
	}

	/* Investigation variables - PART II (other part is places before init block)*/
	//nothing	
}


//##########################################################
//schedules agents, such that the simulation of their behaviour and the reflex evaluation is random and not always in the same order 
species scheduler schedules: shuffle(item+station+transporter);

species transporter parent: superclass schedules:[]{
	item load <- nil;
	map<rgb, point> station_position <- []; //represents the knowledge about positions of already found or communicated stations. Entries have shape [rgb::location]
	
	init{
		
	}
	
	//whenever other transporters are near me - that is: at least one of my adjacent neighbors contains another transporter
	reflex exchange_knowledge when:(!empty(agents_inside(my_cell.neighbors) where (string(type_of(each)) = "transporter"))) {		
		
		list<transporter> neighbor_transporters <- agents_inside(my_cell.neighbors) where (string(type_of(each)) = "transporter"); ////choose ONE random neighbor and share knowledge each cycle
		
		//add all knowledges up, whenever there are differences
		//We ignore differing knowledge about the world - we cannot say for sure who is right (even if one is "more up to date" than the other... it could still be wrong, because the world changed meanwhile..) 	
		
		map<rgb, point> cumulated_knowledge <- station_position;
		
		loop n over: neighbor_transporters{
			
			cumulated_knowledge <- cumulated_knowledge + n.station_position; //all knowledge, including possible contradictions
		}
		
		neighbor_transporters <- neighbor_transporters + self; //add me to this group
		
		
		ask neighbor_transporters{
			
			list<rgb> interested_in <- cumulated_knowledge.keys - station_position.keys; //ignore keys that i already know
			
			loop col over: interested_in{
				add (cumulated_knowledge at col) to: station_position at: col; //add previously unknown keys and values to my knowledge
				//this possibly means that a WRONG (contradictory) value that has been accumulated above is now shared. Last one overwrites all others here. 
			}	
		}		
	}
	
	//if i am empty or do not know where my item's station is -> wander
	reflex random_movement when:((load = nil) or !(station_position contains_key load.color)) {
		
		//generate a list of all my neighbor cells in a random order
		list<shop_floor> s <- shuffle(my_cell.neighbors); //get all cells with distance ONE
		
		loop cell over: s{ //check all cells in order if they are already taken.
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				do take_a_step_to(cell); //if the cell is free - go there		
			}
		}
	}
	
	//if I transport an item and know it's station, I will directly go to nearest neighboring field of this station 
	reflex exact_movement when:((load != nil) and (station_position contains_key load.color)) {
		
		shop_floor target <- shop_floor(station_position at load.color); //The target is the station itself, but we will not enter the stations cell. When we are next to it, our item will be loaded off, s.t. we won't enter the station 
		
		//contains neighboring cells in ascending order of distance, meaning: first cell has least distance
		list<shop_floor> options <- my_cell.neighbors sort_by (each distance_to target);
		
		loop while:!empty(options){ //check all options in order if they are already taken.
			
			shop_floor cell <- first(options);
			
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				do take_a_step_to(cell); //if the cell is free - go there
				break;		
			}else{
				
				//remove unreachable cell from option. Sort rest.
				options <- options - cell;
				options <- options sort_by (each distance_to target);
			}
			
		}
		
		/*if am in the neighborhood of my target and there is NO station, delete MY knowledge.*/
		//I only modify my knowledge, as I know _now_ that it is wrong, but during exchange with other transporter I cannot say for sure if MY knowledge is still correct or not
		if(target.neighbors contains my_cell)
		{
			// I am standing next to where I THINK my station should be. If so: in the next Reflex we deliver it automatically		
			station s <- one_of(station inside target); //there should only be one station per cell, but this ensures that only one is picked.
		
			//if there is no station or it has the wrong color, my knowledge is WRONG
			if((s = nil) or (s.accept_color != load.color)) {
				
				do remove_knowledge(load.color); //remove wrong knowledge
				
				if(s != nil){
					do add_knowledge(s.location, s.accept_color); //nevertheless, if there is a station, update my knowledge
				}
			}	
		}
	}	
	
	//this reflex is for the case that I have a thing and am now looking for a station. Up to now, i DO NOT have to queue
	reflex get_rid_of_thing when: (load != nil){			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each)))); //only ONE (the first cell...)
		list<shop_floor> cell_tmp_list <- (my_cell.neighbors) where (!(empty(station inside (each)))); //get all stations 
		 
		//check all adjacent cells with stations inside 
		loop cell over: cell_tmp_list{
			
			station s <- one_of(station inside cell); //there should only be one station per cell, but this ensures that only one is picked.
		
			//if the station we picked has the color of our item
			if(s.accept_color = load.color) {
				
				/*Update all variables and containers for investigations*/
					put delivered[load.color]+1 key:load.color in: delivered; //count as delivered in respective colo category
					total_delivered <- total_delivered +1; //increase counter for total amount of delivered things by 1
					
					//add current cycle to thing to denote time when it was delivered
					load.cycle_delivered <- cycle; //sent new cycle as state to load
					int cycle_difference <- load.cycle_delivered - load.cycle_created; //calculate the cycle difference to add it to the evaluation variables in the next step
					time_to_deliver_SUM <- time_to_deliver_SUM + cycle_difference ; //add it to the total sum
					mean_of_delivered_cycles <- time_to_deliver_SUM/(total_delivered); //after successful delivery, update average amount of cycles
					
				
				//if i did not know about this station before, add it to my model 
				if(!(station_position contains_key load.color)){
					do add_knowledge(s.location, load.color); // add/update knowledge about new station
				}
		
				do deliver_load(); //load is delivered
				
				break; //as we have loaded off our item, we do not need to check any leftover stations (also it would lead to an expection because load is now nil)
			}
		}		
	}
	
	//search adjacency for a station. If it has a thing, pick it up. Depending in stigmergy settings, also initiate color marks
	reflex search_thing when: load = nil{			
		//get the first cell with a station on it that is adjacent to me
		shop_floor cell_tmp <- (my_cell.neighbors) first_with (!(empty(station inside (each))));
		
		if(cell_tmp != nil) //if this cell is NOT empty, the transporter has a station neighbor
		{
			station s <- first(station inside cell_tmp); //cells can only have one station at a time, hence this list has exactly one entry. 'First' is sufficient to get it.
			
			//as I discovered a station, I add its position to my knowledge if i didn't know about it before 
			if(!(station_position contains_key s.accept_color)){
				do add_knowledge(s.location, s.accept_color); // add/update knowledge about new station  	
			}
						
			//Request state of s to ask about storage. if this NOT nil, a thing has been created and is waiting there and assigned as load.
			load <- s.storage; //take over thing as load from here 
			
			if( load != nil){
				
				//if load is NOT nil now, we took something over. If it would still be nil, then the station was simply empty
				s.storage <- nil; //we took the thing, thus set station's storage to nil
				//Remark: here used to be an update for the load's location, but as the reflex for updating the thing follows immediately after this reflex here, we don't need it
			}
			
		}		
	}
	
	reflex update_thing when: (load != nil){
		ask load{
				my_cell <- myself.my_cell; //just ask the thing you carry to go to the same spot as you.
				location <- myself.my_cell.location;
			}			
	}
	
	action add_knowledge(point pt, rgb col){
		
		add pt at:col to: station_position; // add/update knowledge about new station and assign a point to a color 	
		
	}
	
	action remove_knowledge(rgb col){
		remove key: col from: station_position; // remove knowledge about station 	
		
	}
	
	action deliver_load{
		
		ask load{
			do die;
		}

		load<-nil; //reset load after delivery
	}
	
	action take_a_step_to(shop_floor cell){
				
		my_cell <- cell; //if the cell is free - go there
		location <- my_cell.location;		
	}
			
	aspect base{
		
		draw circle(cell_width) color: #grey border:#black;
	}
	
	aspect info{
		
		draw circle(cell_width) color: #grey border:#black;
		draw replace(name, "transporter", "") size: 10 at: location-(cell_width/2) color: #red;
	}
	
}

//##########################################################
experiment MBA_1_to_many_No_Charts type:gui{
	//parameter "Station placement distribution" category: "Simulation settings" var: selected_placement_mode among:placement_mode; //provides drop down list
		
	output {	
		layout #split;
		 display "Shop floor display" { 
				
		 		grid shop_floor lines: #black;
		 		species shop_floor aspect:info;
		 		species transporter aspect: info;
		 		species station aspect: base;
		 		species item aspect: base;
	
		 }
		 
		  inspect "Knowledge" value: transporter attributes: ["station_position"] type:table;
	 }
	
}

experiment MBA_1_to_many type: gui {

	//Define attributes, actions, a init section and behaviors if necessary

	//list<int> widths <- [25,50,100];
	//list<float> cell_widths <- [2.0,1.0,0.5];
	//list<int> transporter_no <- [17,4*17,4*4*17];
	//list<int> stations_no <- [4,4*4,4*4*4];
	 
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-4*17 ; // 17, 4*17, 16*17
	parameter "No. of stations" category: "Stations" var: no_station<-16; //4, 4*4 (16), 4*4*4 (64)
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<- 100#cycles; //
			
	output {

	layout #split;
	 display "Shop floor display" { 
			
	 		grid shop_floor lines: #black;
	 		species transporter aspect: base;
	 		species station aspect: base;
	 		species item aspect: base;

	 }	 
	  
	display statistics{
						
			chart "Mean cycles to deliver" type:series size:{1 ,0.5} position:{0, 0}{
					data "Mean of delivered cycles" value: mean_of_delivered_cycles color:#purple marker:false ;		
			}
			
			chart "Average thing lifespan" type:series size:{1 ,0.5} position:{0, 0.5}{
				
					data "Average thing lifespan" value: avg_thing_lifespan color: #blue marker: false;		
			}

	 }
	
	 display delivery_information refresh: every(20#cycles){
			 
			chart "total delivered things" type: series size: {1, 0.5} position: {0,0}{				
				data "total delivered things" value: total_delivered color:#red marker:false; 

			}
												 
			chart "Delivery distribution" type:histogram size:{1 ,0.5} position:{0, 0.5} {
					//datalist takes a list of keys and values from the "delivered" map  
					datalist delivered.keys value: delivered.values color:delivered.keys ;
			}
		}	
	}
  
}

/*Runs an amount of simulations in parallel, keeps the seeds and gives the final values after 10k cycles*/
experiment MBA_1_to_many_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{

	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), self.seed, disturbance_cycles ,self.cycle, self.total_delivered, mean_cyc_to_deliver]
          to: "result/3_MBA_results.csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

/*Runs an amount of simulations in parallel, varies the the disturbance cycles from 25 to 500 and gives the final values after 10k cycles*/
experiment MBA_1_to_many_Variation_batch type: batch until: (cycle >= 10000) repeat: 40 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [25#cycles, 50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), self.seed, disturbance_cycles ,self.cycle, self.total_delivered, mean_cyc_to_deliver] //..., ((total_delivered = 0) ? 0 : time_to_deliver_SUM/(total_delivered)) 
          to: "result_var/3_MBA_variation_results.csv" type: "csv" rewrite: false header: true; //rewrite: (int(self) = 0) ? true : false
    	}       
	}		
}
