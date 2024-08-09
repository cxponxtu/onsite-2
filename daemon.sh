#!/bin/bash

time_to_stop=20

fun()
{
        inp=`docker ps --format "{{.ID}}+{{.Networks}}#"`
        while IFS="#" read -a container_array
        do
            for i in "${container_array[@]}"
            do
                IFS="+" read -a splitted_container_array <<< "$i"
                
                # Converting the time to sec
                time=`docker inspect --format='{{.State.StartedAt}}' ${splitted_container_array[0]}`
                time=`echo "$(date +%s) -$(date +%s -d "$time")" | bc`

                # Checking if container is running for more than 15 minutes
                if [ $time -gt $time_to_stop ]
                then
                    len=0

                    # Checking if the network is bridge
                    if [ "${splitted_container_array[1]}" == "bridge" ]
                    then
                        docker stop ${splitted_container_array[0]} >/dev/null 2>&1
                        echo "Stopped container ${splitted_container_array[0]} ." >> daemon.log
                        continue
                    fi

                    # Sorting the containers based on network
                    inp2=`docker ps -f network=${splitted_container_array[1]} --format '{{.ID}}'`
                    count=0
                    while IFS=" " read -a containers_by_network 
                    do                    
                        for j in "${containers_by_network[@]}"
                        do
                            len=$((len+1))

                            # Converting the time to sec
                            time=`docker inspect --format='{{.State.StartedAt}}' $j`
                            time=`echo "$(date +%s) -$(date +%s -d "$time")" | bc`

                            # Checking if containers of network is running more than 15 minutes
                            if [ $time -gt $time_to_stop ]
                            then
                                count=$((count+1))
                            fi
                        done
                    done <<< "$inp2"

                    # Checking if more than half of containers of same network are running more than 15 minutes
                    if [ $(echo "$count > $len/2" | bc) -eq 1 ]
                    then
                        if [ ! -z "$net" ]
                        then
                            if [ "$net" == "${splitted_container_array[1]}" ]
                            then
                                continue
                            fi
                        fi

                        while IFS=" " read -a containers_by_network 
                        do      
                            net=${splitted_container_array[1]}
                            for j in "${containers_by_network[@]}"
                            do
                                docker stop $j >/dev/null 2>&1
                                echo "Container $j stopped" >> daemon.log
                            done
                        done <<< "$inp2"
                    fi
                fi
            done
        done <<< "$inp"

        net=''

}



start()
{
    while true
    do
        fun
        sleep 3
    done
}

if [ "$1" == "start" ]
then
    start &
    echo $! > .pid
    echo "Daemon started"
fi

if [ "$1" == "stop" ]
then
    kill -9 `cat .pid`
    echo "Daemon stopped"
fi