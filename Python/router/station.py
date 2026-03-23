from fastapi import APIRouter
import pymysql
from fastapi.middleware.cors import CORSMiddleware

import config
from pydantic import BaseModel

router = APIRouter()

class StationState(BaseModel):
    station_id: int
    station_number: str
    station_name: str

def connect():
    return pymysql.connect(
        host=config.DB_HOST,
        port=config.DB_PORT,
        user=config.DB_USER,
        password=config.DB_PASSWORD,
        database=config.DB_NAME,
        charset=config.DB_CHARSET,
        autocommit=False
    )

@router.post("/insert")
async def insert(station: StationState):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        insert into station
        (station_number, station_name)
        values (%s, %s)
        """
        curs.execute(sql, (
            station.station_number,
            station.station_name
        ))
        conn.commit()
        return {'result': 'OK'}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.post("/update")
async def update(station: StationState):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        update station set
            station_number = %s,
            station_name = %s
        where station_id = %s
        """
        curs.execute(sql, (
            station.station_number,
            station.station_name,
            station.station_id
        ))
        conn.commit()
        return {'result': 'OK'}
    except Exception as ex:
        conn.rollback()
        print("Error :", ex)
        return {'result': 'Error'}
    finally:
        conn.close()

@router.get("/selectAll")
async def select():
    conn = connect()
    curs = conn.cursor()
    try:
        sql = "select * from station"
        curs.execute(sql)
        rows = curs.fetchall()

        result = [{
            'station_id': row[0],
            'station_number': row[1],
            'station_name': row[2]
        } for row in rows]

        return {'results': result}
    finally:
        conn.close()