/**
* Name: SRA Naive Transporte
* Author: Sebastian Schmid
* Description: SRA for comparison purposes to MBA NonCom   
* Tags: 
*/



@no_warning
model Naive

import "../Station_Item.gaml"

global{	
		
	init{
		create transporter number: no_transporter;		
	
	}
	

	
}

//##########################################################
species scheduler schedules: shuffle(item+station+transporter);


species transporter parent: superclass {
	item load <- nil;
	
	float amount_of_steps<- 0.0; //the amount of steps this transporter made after it pickep up an item   
	
	init{
	
	}
	
	//whatever you do, you always wander around - as long as there is no other transporter blocking you or a station in your way
	reflex wander {
		
		//generate a list of all my neighbor cells in a random order
		list<shop_floor> s <- shuffle(my_cell.neighbors); //get all cells with distance ONE
		
		loop cell over: s{ //check all cells in order if they are already taken.
			if(empty(transporter inside cell) and empty(station inside cell)) //as long as there is no other transporter or station
			{
				my_cell <- cell; //if the cell is free - go there
				location <- my_cell.location;
			}
		}

	}		
	
	//this reflex is for the case that I have a item and am now looking for a station. Up to now, i DO NOT have to queue
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
					amount_of_steps <- 0.0; //reset amount of steps
								
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
			
			//Request state of s to ask about storage. if this NOT nil, a item has been created and is waiting there and assigned as load.
			load <- s.storage; //thanks, we'll take your item as load over from here 
			
			if( load != nil){
				
				//if load is NOT nil now, we took someitem over. If it would still be nil, then the station was simply empty
				s.storage <- nil; //we took the thing, thus set station's storage to nil
				//Remark: here used to be an update for the load's location, but as the reflex for updating the thing follows immediately after this reflex here, we don't need it
			}
			
		}		
	}
	
	//updates position of the current load s.t. it appears at the same posiiton as the transporter
	reflex update_thing when: (load != nil){
		ask load{
				my_cell <- myself.my_cell; //just ask the thing you carry to go to the same spot as you.
				location <- myself.my_cell.location;
			}			
	}
				
	action deliver_load{
		ask load{
			do die;
		}

		load<-nil; //reset load after delivery
	}
	
			
	aspect base{
		
		draw circle(cell_width) color: #grey border:#black;
	}
	
	aspect info{
		
		draw circle(cell_width) color: #grey border:#black;
		draw replace(name, "transporter", "") size: 10 at: location-(cell_width) color: #red;
	}
	
}



//##########################################################

experiment Naive_SRA type: gui {
	// Define parameters here if necessary
	
	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles<-500;  
		
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-64 ; // 17, 64 (4*17), 272 (4*4*17)
	parameter "No. of stations" category: "Stations" var: no_station<-4*4; //4, 16 (4*4), 64 (4*4*4)
	
	parameter "Measure performance" category: "Measure" var: performance <- true;
	parameter "Measure knowledge" category: "Measure" var: knowledge <- false;
	
	//Define attributes, actions, a init section and behaviors if necessary
	
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
			
			/* 
			chart "Average thing lifespan" type:series size:{1 ,0.5} position:{0, 0.5}{
				
					data "Average thing lifespan" value: avg_thing_lifespan color: #blue marker: false;		
			}*/

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

/*###########################################################*/
/*Runs an amount of simulations in parallel, varies the the disturbance cycles*/
experiment Performance type: batch until: (cycle >= 5000) repeat: 20 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-64 ; // 17, 64 (4*17), 272 (4*4*17)
	parameter "No. of stations" category: "Stations" var: no_station<-16; //4, 16 (4*4), 64 (4*4*4)
	
	
	parameter "Measure performance" category: "Measure" var: performance <- true;
	parameter "Measure knowledge" category: "Measure" var: knowledge <- false;
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	save [int(self), disturbance_cycles, self.cycle, self.total_delivered, mean_cyc_to_deliver]
           to: "simulation_results/performance/Naive_SRA_"+ experiment.name +"_"+ string(width)+".csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}

/*Runs an amount of simulations in parallel, varies the the disturbance cycles*/
experiment Knowledge type: batch until: (cycle >= 5000) repeat: 20 autorun: true keep_seed: true{ 

	parameter "Disturbance cycles" category: "Simulation settings" var: disturbance_cycles among: [50#cycles, 100#cycles, 250#cycles, 500#cycles]; //amount of cycles until stations change their positions
	
	parameter var: width<-50; //25, 50, 100	
	parameter var: cell_width<- 1.0; //2.0, 1.0 , 0.5
	parameter "No. of transporters" category: "Transporter" var: no_transporter<-64 ; // 17, 64, 272
	parameter "No. of stations" category: "Stations" var: no_station<-16; //4, 16 (4*4), 64 (4*4*4)
	
	
	parameter "Measure performance" category: "Measure" var: performance <- false;
	parameter "Measure knowledge" category: "Measure" var: knowledge <- true;
	
	
	reflex save_results_explo {
    ask simulations {
    	
    	float mean_cyc_to_deliver <- ((self.total_delivered = 0) ? 0 : self.time_to_deliver_SUM/(self.total_delivered)); //
    	
    	float avg_traffic <- float( self.total_traffic ) / self.no_transporter; //average amount of messages sent per transporter for whole simulation duration
    	
    	list<float> t_avgs <- [];
    	
		//calculate average delay per update (only applicable if updates have been received (-> updates != 0))
    	ask self.transporter{

    		add -1 to: t_avgs; //SRA donts receive updates, hence all NaN
    				
    	}
    	
    	save [int(self), disturbance_cycles, self.cycle, mean(self.residue), avg_traffic, mean(t_avgs)]
           to: "simulation_results/knowledge/Naive_SRA_"+ experiment.name +"_"+ string(width)+".csv" type: "csv" rewrite: false header: true; 
    	}       
	}		
}