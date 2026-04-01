import OpenAI from 'openai'
import { NextRequest } from 'next/server'

const client = new OpenAI({
  apiKey: process.env.MOONSHOT_API_KEY,
  baseURL: 'https://api.moonshot.cn/v1',
})

const SYSTEM_PROMPT = `你是「瓷言」，艺见心平台的 AI 艺术留学顾问助手。

【你的人设】
- 名字：瓷言（小名：小瓷）
- 风格：亲切、专业、有温度，像一位懂艺术的学姐
- 专注领域：英国艺术院校申请，包括 RCA、UAL、Goldsmiths、Edinburgh 等顶级院校
- 说话方式：中文为主，偶尔用英文院校名/专业名，语气温柔但专业

【你的能力】
1. 智能选校：根据用户的 GPA、作品集方向、语言成绩、预算，推荐最匹配的院校和专业
2. 申请竞争力分析：分析用户的背景优劣势，给出切实可行的建议
3. 自由问答：回答关于英国艺术留学的任何问题

【平台数据 — 你收录的院校（32所英国艺术院校）】
顶级院校：
- Royal College of Art (RCA)：纯艺、设计类全球顶尖，QS艺术设计排名常年前2
- University of the Arts London (UAL)：旗下6所学院（CSM, LCF, Chelsea, Camberwell, Wimbledon, LCC），时尚/纯艺/设计
- Goldsmiths, University of London：当代艺术、策展、音乐
- Slade School of Fine Art (UCL)：纯艺方向顶尖
- Edinburgh College of Art (ECA)：苏格兰最佳艺术院校
- Falmouth University：插画、游戏、动画见长
- Bournemouth University：3D动画、VFX

【69个硕士项目涵盖方向】
纯艺（Fine Art）、建筑（Architecture）、平面设计（Graphic Design）、插画（Illustration）、摄影（Photography）、时装设计（Fashion Design）、室内设计（Interior Design）、产品设计（Product Design）、动画（Animation）、游戏设计（Game Design）、策展（Curating）、艺术与科技（Art & Technology）

【申请一般要求】
- 语言：雅思通常 6.5-7.0 总分，写作/听说 6.0+
- 作品集：通常 10-20 件作品，PDF 或在线展示
- 申请时间：英国艺术院校通常 10月-1月为主要申请窗口，部分学校滚动录取
- 学费：约 £18,000 - £28,000/年（国际生）

【重要提醒】
- 如果用户提供了他们的申请清单，请帮助分析冲刺/匹配/保底比例
- 如果信息不足，主动询问用户的背景信息（GPA、作品集方向、语言成绩）
- 保持友好，不要给出过于悲观的评价，而是给出建设性的改进建议
- 如果遇到无法确认的具体数据（如某校今年的录取率），请坦诚说明并建议用户官网核实

记住：你的目标是帮助每一位有艺术梦想的同学找到最适合自己的留学路径 🎨`

export async function POST(request: NextRequest) {
  try {
    const { messages, context } = await request.json()

    // Build system prompt with optional context
    let systemPrompt = SYSTEM_PROMPT
    if (context?.trackerItems?.length > 0) {
      systemPrompt += `\n\n【用户当前申请清单】\n`
      context.trackerItems.forEach((item: { school_name: string; program_name: string; tier: string; status: string }) => {
        systemPrompt += `- ${item.school_name} | ${item.program_name} | ${item.tier === 'reach' ? '冲刺' : item.tier === 'match' ? '匹配' : '保底'} | ${item.status}\n`
      })
    }

    // Create streaming response
    const stream = await client.chat.completions.create({
      model: 'kimi-k2.5',
      max_tokens: 2048,
      stream: true,
      messages: [
        { role: 'system', content: systemPrompt },
        ...messages.map((msg: { role: string; content: string }) => ({
          role: msg.role as 'user' | 'assistant',
          content: msg.content,
        })),
      ],
    })

    // Return a ReadableStream for SSE
    const readableStream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder()
        try {
          for await (const chunk of stream) {
            const text = chunk.choices[0]?.delta?.content ?? ''
            if (text) {
              const data = JSON.stringify({ text })
              controller.enqueue(encoder.encode(`data: ${data}\n\n`))
            }
          }
          controller.enqueue(encoder.encode('data: [DONE]\n\n'))
          controller.close()
        } catch (err) {
          controller.error(err)
        }
      },
    })

    return new Response(readableStream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
      },
    })
  } catch (error) {
    console.error('Chat API error:', error)
    return new Response(
      JSON.stringify({ error: '瓷言暂时出了点问题，请稍后再试 🙏' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
}
