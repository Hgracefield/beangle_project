from fastapi import APIRouter
import pymysql
from fastapi.middleware.cors import CORSMiddleware

import config
from pydantic import BaseModel

router = APIRouter()

class WorkState(BaseModel):
    work_id: int
    worker_id: int
    station_id: int
    count: int
    worktime: str

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
async def insert(work: WorkState):
    conn = connect()
    curs = conn.cursor()
    try:
        duplicate_sql = """
        select count(*)
        from work
        where station_id = %s
          and worktime = %s
        """
        curs.execute(duplicate_sql, (
            work.station_id,
            work.worktime
        ))
        duplicate_count = curs.fetchone()[0]

        if duplicate_count > 0:
            conn.rollback()
            return {'result': 'DUPLICATE'}

        sql = """
        insert into work
        (worker_id, station_id, count, worktime, timestamp)
        values (%s, %s, %s, %s, now())
        """
        curs.execute(sql, (
            work.worker_id,
            work.station_id,
            work.count,
            work.worktime
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
async def update(work: WorkState):
    conn = connect()
    curs = conn.cursor()
    try:
        sql = """
        update work set
            worker_id = %s,
            station_id = %s,
            count = %s,
            worktime = %s,
            timestamp = now()
        where work_id = %s
        """
        curs.execute(sql, (
            work.worker_id,
            work.station_id,
            work.count,
            work.
            work.work_id
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
        sql = "select * from work"
        curs.execute(sql)
        rows = curs.fetchall()

        result = [{
            'work_id': row[0],
            'worker_id': row[1],
            'station_id': row[2],
            'count': row[3],
            'worktime': row[4],
            'timestamp':row[5]
        } for row in rows]

        return {'results': result}
    finally:
        conn.close()
